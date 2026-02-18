class Agent::Tools::Remember < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "remember",
        description: "Save something to long-term memory. Use this to remember important facts, preferences, or context about the user or conversation.",
        parameters: {
          type: "object",
          properties: {
            content: { type: "string", description: "The information to remember" },
            importance: { type: "number", description: "Importance score from 0.0 (low) to 1.0 (high). Defaults to 0.6." }
          },
          required: [ "content" ]
        }
      }
    }
  end

  def call
    content = arguments["content"]
    return "Error: content is required" if content.blank?

    importance = arguments.fetch("importance", 0.6).to_f.clamp(0.0, 1.0)

    Rails.logger.info("[Agent::Tools::Remember] agent=#{agent.name} importance=#{importance} content=#{content.truncate(200)}")

    memory = agent.memories.create!(content: content, source: "agent", importance: importance)

    embedding = Agent::Embedding.new(agent.account)
    if embedding.available?
      vec = embedding.embed(content)
      memory.update_columns(embedding: vec.pack("f*")) if vec.present?
    end

    "Remembered (id:#{memory.id}): #{content.truncate(100)}"
  end
end
