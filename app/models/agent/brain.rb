class Agent::Brain
  MAX_ITERATIONS = 50

  attr_reader :agent, :chat

  def initialize(agent, chat)
    @agent = agent
    @chat = chat
  end

  def respond(user_message: nil, user_message_record: nil, on_message: nil, on_tool_complete: nil, &on_token)
    @system_prompt = prompt_builder.system_prompt(
      chat: chat,
      current_message: user_message,
      current_message_record: user_message_record
    )
    iterations = 0

    loop do
      if chat.reload.halted?
        return chat.messages.create!(message_sender_attrs(
          role: "assistant",
          content: "Stopped."
        ))
      end

      if iterations >= MAX_ITERATIONS
        return chat.messages.create!(message_sender_attrs(
          role: "assistant",
          content: "I wasn't able to complete the task within the tool call limit."
        ))
      end

      response = think(&on_token)
      iterations += 1

      if response.tool_calls?
        msg = persist_assistant(response)
        on_message&.call(msg)

        response.tool_calls.each do |tc|
          result = Agent::ToolRegistry.execute(tc.name, tc.parsed_arguments, agent: agent, context: { chat: chat })
          tool_msg = chat.messages.create!(message_sender_attrs(role: "tool", content: result, tool_call_id: tc.id))
          on_message&.call(tool_msg)
        end

        on_tool_complete&.call
      else
        next if response.content.blank?

        message = chat.messages.create!(message_sender_attrs(role: "assistant", content: response.content))
        Agent::Compaction.new(agent, chat).maybe_compact
        return message
      end
    end
  end

  private
    def think(&on_token)
      if (provider_plugin = agent.plugins.detect { |p| p.provider_mode?(agent) })
        klass = provider_plugin.provider_entrypoint_class
        instance = klass.new(agent: agent, plugin: provider_plugin)
        return instance.chat(
          messages: build_messages,
          model: agent.model,
          chat: chat,
          &on_token
        )
      end

      provider = agent.resolve_provider
      raise Providers::Error, "No provider configured" unless provider

      provider.client.chat(
        messages: build_messages,
        model: agent.model,
        tools: Agent::ToolRegistry.definitions(agent: agent),
        &on_token
      )
    end

    TOOL_RESULT_WINDOW = 15

    def build_messages
      messages = [ { role: "system", content: @system_prompt } ]
      all_msgs = chat.messages.where(compacted_at: nil).includes(:sender).order(:created_at).to_a
      window_start = all_msgs.length - TOOL_RESULT_WINDOW

      all_msgs.each_with_index do |msg, i|
        content = msg.content
        sender_user = (msg.sender if msg.sender.is_a?(User))
        if msg.role == "user" && sender_user.present? && chat.group?
          content = "[#{sender_user.first_name}]: #{content}"
        end
        # Remap "system" messages in chat history to "user" role
        # with a prefix. LLMs don't expect system messages mid-chat
        # and treat them as new instructions, causing duplicate responses.
        if msg.role == "system"
          content = "[System] #{content}"
          role = "user"
        else
          role = msg.role
        end

        # Strip bulky tool results outside the recent window.
        # The assistant tool_calls message stays so the LLM knows what
        # was called, but the full output is no longer needed.
        if role == "tool" && i < window_start
          content = "[result filtered for compacting]"
        end

        entry = { role: role, content: content }
        if msg.tool_calls.present?
          entry[:tool_calls] = msg.tool_calls.map { |tc|
            tc.merge("id" => Providers::ToolCall.normalize_id(tc["id"]))
          }
        end
        entry[:tool_call_id] = Providers::ToolCall.normalize_id(msg.tool_call_id) if msg.tool_call_id.present?
        messages << entry
      end

      messages
    end

    def persist_assistant(response)
      chat.messages.create!(message_sender_attrs(
        role: "assistant",
        content: response.content,
        tool_calls: response.tool_calls.map { |tc|
          { id: tc.id, type: "function", function: { name: tc.name, arguments: tc.arguments } }
        }
      ))
    end

    def message_sender_attrs(attrs)
      return attrs unless chat.is_a?(Chat)

      attrs.merge(sender: agent)
    end

    def prompt_builder
      @prompt_builder ||= Agent::PromptBuilder.new(agent)
    end
end
