class Agent::Tools::UpdatePersonality < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "update_personality",
        description: "Update your personality description. This changes how you present yourself and your behavioral traits.",
        parameters: {
          type: "object",
          properties: {
            content: { type: "string", description: "The new personality text" }
          },
          required: [ "content" ]
        }
      }
    }
  end

  def call
    content = arguments["content"]
    return "Error: content is required" if content.blank?

    agent.update!(personality: content)
    "Personality updated."
  end
end
