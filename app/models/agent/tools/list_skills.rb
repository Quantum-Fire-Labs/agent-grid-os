class Agent::Tools::ListSkills < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "list_skills",
        description: "List all your enabled skills.",
        parameters: { type: "object", properties: {} }
      }
    }
  end

  def call
    skills = agent.skills.order(:name)
    return "No skills enabled." if skills.empty?

    lines = skills.map do |s|
      s.description.present? ? "- #{s.name}: #{s.description}" : "- #{s.name}"
    end

    lines.join("\n")
  end
end
