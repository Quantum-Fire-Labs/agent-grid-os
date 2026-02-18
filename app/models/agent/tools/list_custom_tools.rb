class Agent::Tools::ListCustomTools < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "list_custom_tools",
        description: "List all your registered custom tools.",
        parameters: { type: "object", properties: {} }
      }
    }
  end

  def call
    tools = agent.custom_tools.order(:name)
    return "No custom tools registered." if tools.empty?

    lines = tools.map do |t|
      "- #{t.tool_name}: #{t.description} (entrypoint: #{t.entrypoint})"
    end

    lines.join("\n")
  end
end
