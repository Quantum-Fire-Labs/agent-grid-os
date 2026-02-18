class Agent::Tools::RegisterTool < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "register_tool",
        description: "Register a workspace script as a reusable tool. The script will receive a JSON object on stdin and should write its result to stdout. The tool will be available as custom_<name> on the next turn.",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "Tool name (lowercase, alphanumeric and underscores, e.g. 'lint'). Will be callable as custom_<name>." },
            description: { type: "string", description: "What the tool does" },
            entrypoint: { type: "string", description: "Shell command to run the script (e.g. 'python workspace/lint.py' or 'bash workspace/check.sh')" },
            parameter_schema: { type: "object", description: "Optional JSON Schema for the tool's parameters" }
          },
          required: %w[name description entrypoint]
        }
      }
    }
  end

  def call
    name = arguments["name"]
    return "Error: name is required" if name.blank?
    return "Error: description is required" if arguments["description"].blank?
    return "Error: entrypoint is required" if arguments["entrypoint"].blank?

    custom_tool = agent.custom_tools.find_or_initialize_by(name: name)
    custom_tool.assign_attributes(
      description: arguments["description"],
      entrypoint: arguments["entrypoint"],
      parameter_schema: arguments["parameter_schema"] || {}
    )

    if custom_tool.save
      "Registered tool '#{custom_tool.tool_name}'. It will be available on the next turn."
    else
      "Error: #{custom_tool.errors.full_messages.join(", ")}"
    end
  end
end
