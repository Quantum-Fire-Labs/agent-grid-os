class Agent::Brain
  MAX_ITERATIONS = 50

  attr_reader :agent, :conversation

  def initialize(agent, conversation)
    @agent = agent
    @conversation = conversation
  end

  def respond(user_message: nil, user_message_record: nil, on_message: nil, on_tool_complete: nil, &on_token)
    @system_prompt = prompt_builder.system_prompt(
      conversation: conversation,
      current_message: user_message,
      current_message_record: user_message_record
    )
    iterations = 0

    loop do
      response = think(&on_token)
      iterations += 1

      if response.tool_calls?
        msg = persist_assistant(response)
        on_message&.call(msg)

        if iterations >= MAX_ITERATIONS
          return conversation.messages.create!(
            role: "assistant",
            content: "I wasn't able to complete the task within the tool call limit."
          )
        end

        response.tool_calls.each do |tc|
          result = Agent::ToolRegistry.execute(tc.name, tc.parsed_arguments, agent: agent, context: { conversation: conversation })
          tool_msg = conversation.messages.create!(role: "tool", content: result, tool_call_id: tc.id)
          on_message&.call(tool_msg)
        end

        on_tool_complete&.call
      else
        next if response.content.blank?

        message = conversation.messages.create!(role: "assistant", content: response.content)
        Agent::Compaction.new(agent, conversation).maybe_compact
        return message
      end
    end
  end

  private

    def think(&on_token)
      provider = agent.resolve_provider
      raise Providers::Error, "No provider configured" unless provider

      provider.client.chat(
        messages: build_messages,
        model: agent.model,
        tools: Agent::ToolRegistry.definitions(agent: agent),
        &on_token
      )
    end

    def build_messages
      messages = [ { role: "system", content: @system_prompt } ]

      conversation.messages.where(compacted_at: nil).includes(:user).order(:created_at).each do |msg|
        content = msg.content
        if msg.role == "user" && msg.user.present? && conversation.kind_group?
          content = "[#{msg.user.first_name}]: #{content}"
        end
        # Remap "system" messages in conversation history to "user" role
        # with a prefix. LLMs don't expect system messages mid-conversation
        # and treat them as new instructions, causing duplicate responses.
        if msg.role == "system"
          content = "[System] #{content}"
          role = "user"
        else
          role = msg.role
        end
        entry = { role: role, content: content }
        entry[:tool_calls] = msg.tool_calls if msg.tool_calls.present?
        entry[:tool_call_id] = msg.tool_call_id if msg.tool_call_id.present?
        messages << entry
      end

      messages
    end

    def persist_assistant(response)
      conversation.messages.create!(
        role: "assistant",
        content: response.content,
        tool_calls: response.tool_calls.map { |tc|
          { id: tc.id, type: "function", function: { name: tc.name, arguments: tc.arguments } }
        }
      )
    end

    def prompt_builder
      @prompt_builder ||= Agent::PromptBuilder.new(agent)
    end
end
