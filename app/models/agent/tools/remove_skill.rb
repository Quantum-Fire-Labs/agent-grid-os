class Agent::Tools::RemoveSkill < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "remove_skill",
        description: "Remove a skill from the account. This deletes it for all agents.",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "The name of the skill to remove" }
          },
          required: [ "name" ]
        }
      }
    }
  end

  def call
    name = arguments["name"]
    return "Error: name is required" if name.blank?

    skill = agent.account.skills.find_by(name: name)
    return "Error: no skill named '#{name}'" unless skill

    skill.destroy!
    "Removed skill '#{name}'."
  end
end
