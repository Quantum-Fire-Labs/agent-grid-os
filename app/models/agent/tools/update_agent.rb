class Agent::Tools::UpdateAgent < Agent::Tools::Base
  ALLOWED_PARAMS = %w[title description personality instructions network_mode workspace_enabled].freeze

  def self.definition
    {
      type: "function",
      function: {
        name: "update_agent",
        description: "Update an existing agent by name.",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "Name of the agent to update (required)" },
            title: { type: "string", description: "Short title or role" },
            description: { type: "string", description: "Description of the agent" },
            personality: { type: "string", description: "Personality traits and tone" },
            instructions: { type: "string", description: "Instructions for the agent" },
            network_mode: { type: "string", enum: %w[none allowed full], description: "Network access level" },
            workspace_enabled: { type: "boolean", description: "Enable or disable Docker workspace" }
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

    attrs = arguments.slice(*ALLOWED_PARAMS)
    return "Error: no fields to update." if attrs.empty?

    target.update!(attrs)
    "Updated agent '#{name}'."
  rescue ActiveRecord::RecordInvalid => e
    "Error: #{e.message}"
  end
end
