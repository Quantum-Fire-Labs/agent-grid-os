class Agent::Tools::CreateAgent < Agent::Tools::Base
  ALLOWED_PARAMS = %w[name title description personality instructions network_mode workspace_enabled].freeze

  def self.definition
    {
      type: "function",
      function: {
        name: "create_agent",
        description: "Create a new agent in the account.",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "Unique name for the agent (required)" },
            title: { type: "string", description: "Short title or role" },
            description: { type: "string", description: "Description of the agent" },
            personality: { type: "string", description: "Personality traits and tone" },
            instructions: { type: "string", description: "Instructions for the agent" },
            network_mode: { type: "string", enum: %w[none allowed full], description: "Network access level (default: none)" },
            workspace_enabled: { type: "boolean", description: "Enable Docker workspace (default: false)" }
          },
          required: %w[name]
        }
      }
    }
  end

  def call
    name = arguments["name"]
    return "Error: name is required" if name.blank?

    attrs = arguments.slice(*ALLOWED_PARAMS)
    new_agent = agent.account.agents.create!(attrs)

    assign_member_users(new_agent)

    "Created agent '#{new_agent.name}'."
  rescue ActiveRecord::RecordInvalid => e
    "Error: #{e.message}"
  end

  private
    def assign_member_users(new_agent)
      return unless context[:chat]

      context[:chat].users.where(role: :member).each do |user|
        new_agent.agent_users.create!(user: user)
      end
    end
end
