class Agent::Tools::UnregisterTool < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "unregister_tool",
        description: "Remove a previously registered custom tool.",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "The tool name (without the custom_ prefix)" }
          },
          required: [ "name" ]
        }
      }
    }
  end

  def call
    name = arguments["name"]
    return "Error: name is required" if name.blank?

    custom_tool = agent.custom_tools.find_by(name: name)
    return "Error: no custom tool named '#{name}'" unless custom_tool

    custom_tool.destroy!
    "Unregistered tool 'custom_#{name}'."
  end
end
