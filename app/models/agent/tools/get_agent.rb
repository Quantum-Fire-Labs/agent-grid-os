class Agent::Tools::GetAgent < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "get_agent",
        description: "Get full details of a specific agent by name.",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "Name of the agent to look up" }
          },
          required: %w[name]
        }
      }
    }
  end

  def call
    name = arguments["name"]
    return "Error: name is required" if name.blank?

    target = agent.account.agents.find_by(name: name)
    return "Error: no agent named '#{name}' found." unless target

    fields = {
      name: target.name,
      title: target.title,
      description: target.description,
      personality: target.personality,
      instructions: target.instructions,
      status: target.status,
      network_mode: target.network_mode,
      workspace_enabled: target.workspace_enabled?,
      orchestrator: target.orchestrator?
    }

    fields.map { |k, v| "#{k}: #{v.nil? ? "(not set)" : v}" }.join("\n")
  end
end
