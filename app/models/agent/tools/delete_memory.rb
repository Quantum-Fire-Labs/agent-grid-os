class Agent::Tools::DeleteMemory < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "delete_memory",
        description: "Delete a memory.",
        parameters: {
          type: "object",
          properties: {
            memory_id: { type: "integer", description: "The ID of the memory to delete" }
          },
          required: [ "memory_id" ]
        }
      }
    }
  end

  def call
    memory = agent.memories.find(arguments["memory_id"])

    Rails.logger.info("[Agent::Tools::DeleteMemory] agent=#{agent.name} memory_id=#{memory.id}")

    memory.destroy!

    "Memory #{arguments["memory_id"]} deleted."
  rescue ActiveRecord::RecordNotFound
    "Error: memory #{arguments["memory_id"]} not found"
  end
end
