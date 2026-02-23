class Agent::Compaction
  def initialize(agent, chat)
    @agent = agent
    @chat = chat
  end

  def maybe_compact
    # Get uncompacted messages
    uncompacted = @chat.messages.where(compacted_at: nil).order(:created_at)
    return if uncompacted.count < 10

    # Call LLM to detect topic shift
    provider = @agent.resolve_provider(designation: "default")
    return unless provider

    messages_text = uncompacted.map { |m| "#{m.role}: #{m.content}" }.join("\n\n")

    prompt_messages = [
      { role: "system", content: compaction_system_prompt },
      { role: "user", content: "Here are the chat messages:\n\n#{messages_text}" }
    ]

    response = provider.client.chat(messages: prompt_messages, model: @agent.model || provider.model)
    return unless response.content

    parsed = parse_response(response.content)
    return unless parsed && parsed["compact"]

    ActiveRecord::Base.transaction do
      compact_messages(uncompacted, parsed["keep_from_index"] || uncompacted.count)
      store_memories(parsed["memories"] || [])
    end

    Agent::AutoDemotion.new(@agent).run
  rescue => e
    Rails.logger.error("Agent::Compaction failed: #{e.message}")
  end

  private

    def compaction_system_prompt
      <<~PROMPT
        You analyze chat history and detect topic shifts. When the chat has clearly moved to a new topic, you extract key information from the old topic as summary memories.

        Respond with JSON only:
        {
          "compact": true/false,
          "memories": ["summary statement 1", "summary statement 2"],
          "keep_from_index": <integer index of first message to keep (0-based)>
        }

        Rules:
        - Set "compact" to true only if there's a clear topic shift
        - Extract 1-5 concise summary memories from the OLD topic (before the shift)
        - "keep_from_index" should point to where the new topic begins
        - If no clear topic shift, set "compact" to false
      PROMPT
    end

    def parse_response(content)
      json_match = content.match(/\{.*\}/m)
      return nil unless json_match
      JSON.parse(json_match[0])
    rescue JSON::ParserError
      nil
    end

    def compact_messages(uncompacted, keep_from_index)
      messages_array = uncompacted.to_a
      cutoff = [ keep_from_index, messages_array.length ].min

      # Walk messages and compact in atomic turn groups
      ids_to_compact = []
      i = 0
      while i < cutoff
        msg = messages_array[i]
        ids_to_compact << msg.id

        # If this is an assistant message with tool_calls, compact the subsequent tool result messages too
        if msg.role == "assistant" && msg.tool_calls.present?
          j = i + 1
          while j < messages_array.length && messages_array[j].role == "tool"
            ids_to_compact << messages_array[j].id
            j += 1
          end
        end

        i += 1
      end

      Message.where(id: ids_to_compact).update_all(compacted_at: Time.current) if ids_to_compact.any?
    end

    def store_memories(summaries)
      return if summaries.empty?

      embedding = Agent::Embedding.new(@agent.account)
      vectors = embedding.available? ? embedding.embed_batch(summaries) : []

      summaries.first(5).each_with_index do |summary, i|
        memory = @agent.memories.create!(
          content: summary,
          source: "compaction",
          importance: 0.7
        )

        vec = vectors[i]
        memory.update_columns(embedding: vec.pack("f*")) if vec.present?
      end
    end
end
