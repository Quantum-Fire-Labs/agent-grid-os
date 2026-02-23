class Agent::Tools::CreateSkill < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "create_skill",
        description: "Create or update a skill. Skills are reusable instructions that get injected into your system prompt to guide your behavior. Created skills are available for any agent in this account to enable.",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "Skill name (e.g. 'Code Review Guidelines')" },
            description: { type: "string", description: "Brief description of what this skill covers" },
            body: { type: "string", description: "The full skill instructions that will be added to your system prompt" }
          },
          required: %w[name body]
        }
      }
    }
  end

  def call
    name = arguments["name"]
    return "Error: name is required" if name.blank?
    return "Error: body is required" if arguments["body"].blank?

    skill = agent.account.skills.find_or_initialize_by(name: name)
    skill.assign_attributes(
      description: arguments["description"],
      body: arguments["body"]
    )

    if skill.save
      agent.agent_skills.find_or_create_by!(skill: skill)
      verb = skill.previously_new_record? ? "Created" : "Updated"
      "#{verb} skill '#{skill.name}'. It will be active in your system prompt on the next turn."
    else
      "Error: #{skill.errors.full_messages.join(", ")}"
    end
  end
end
