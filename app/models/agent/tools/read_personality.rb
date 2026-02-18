class Agent::Tools::ReadPersonality < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "read_personality",
        description: "Read your current personality description. Returns the personality text that shapes your behavior and tone.",
        parameters: {
          type: "object",
          properties: {}
        }
      }
    }
  end

  def call
    agent.personality.presence || "(No personality set.)"
  end
end
