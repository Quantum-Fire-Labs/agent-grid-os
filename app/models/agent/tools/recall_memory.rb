class Agent::Tools::RecallMemory < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "recall_memory",
        description: "Search through memories by keyword.",
        parameters: {
          type: "object",
          properties: {
            query: { type: "string", description: "Keyword to search for in memory content" },
            scope: { type: "string", description: "Which memories to search: active, dormant, or all. Defaults to all.", enum: [ "active", "dormant", "all" ] },
            limit: { type: "integer", description: "Maximum number of results to return. Defaults to 10." }
          },
          required: [ "query" ]
        }
      }
    }
  end

  def call
    query = arguments["query"]
    return "Error: query is required" if query.blank?

    scope     = arguments.fetch("scope", "all")
    limit_val = arguments.fetch("limit", 10).to_i.clamp(1, 50)

    Rails.logger.info("[Agent::Tools::RecallMemory] agent=#{agent.name} query=#{query.truncate(100)} scope=#{scope} limit=#{limit_val}")

    memories = agent.memories.where("content LIKE ?", "%#{query}%")
    memories = memories.where(state: scope) unless scope == "all"
    memories = memories.limit(limit_val)

    return "No memories found matching \"#{query}\"." if memories.empty?

    lines = memories.map do |m|
      "[id:#{m.id} state:#{m.state} importance:#{m.importance}] #{m.content.truncate(200)}"
    end

    "Found #{memories.size} #{"memory".pluralize(memories.size)}:\n\n#{lines.join("\n")}"
  end
end
