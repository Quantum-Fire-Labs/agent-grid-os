class Agent::Tools::ListAgents < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "list_agents",
        description: "List all agents in the account. Returns each agent's name, title, status, and orchestrator flag.",
        parameters: {
          type: "object",
          properties: {}
        }
      }
    }
  end

  def call
    agents = agent.account.agents.order(:name)
    return "No agents found." if agents.none?

    lines = agents.map do |a|
      parts = [ a.name ]
      parts << "(#{a.title})" if a.title.present?
      parts << "[#{a.status}]"
      parts << "[orchestrator]" if a.orchestrator?
      "- #{parts.join(" ")}"
    end

    "Agents (#{agents.size}):\n#{lines.join("\n")}"
  end
end
