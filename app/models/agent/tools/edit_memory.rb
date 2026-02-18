class Agent::Tools::EditMemory < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "edit_memory",
        description: "Edit the content of an existing memory.",
        parameters: {
          type: "object",
          properties: {
            memory_id: { type: "integer", description: "The ID of the memory to edit" },
            content: { type: "string", description: "The updated memory content" }
          },
          required: [ "memory_id", "content" ]
        }
      }
    }
  end

  def call
    content = arguments["content"]
    return "Error: content is required" if content.blank?

    memory = agent.memories.find(arguments["memory_id"])

    Rails.logger.info("[Agent::Tools::EditMemory] agent=#{agent.name} memory_id=#{memory.id}")

    memory.update!(content: content)

    if memory.active?
      embedding = Agent::Embedding.new(agent.account)
      if embedding.available?
        vec = embedding.embed(content)
        memory.update_columns(embedding: vec.pack("f*")) if vec.present?
      end
    end

    "Memory #{memory.id} updated: #{content.truncate(100)}"
  rescue ActiveRecord::RecordNotFound
    "Error: memory #{arguments["memory_id"]} not found"
  end
end
