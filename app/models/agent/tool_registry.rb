class Agent::ToolRegistry
  TOOLS = {
    "web_fetch"          => Agent::Tools::WebFetch,
    "read_personality"   => Agent::Tools::ReadPersonality,
    "update_personality" => Agent::Tools::UpdatePersonality,
    "remember"           => Agent::Tools::Remember,
    "edit_memory"        => Agent::Tools::EditMemory,
    "delete_memory"      => Agent::Tools::DeleteMemory,
    "recall_memory"      => Agent::Tools::RecallMemory
  }.freeze

  DATA_TOOLS = {
    "list_app_tables"    => Agent::Tools::ListAppTables,
    "query_app_data"     => Agent::Tools::QueryAppData,
    "insert_app_data"    => Agent::Tools::InsertAppData,
    "update_app_data"    => Agent::Tools::UpdateAppData,
    "delete_app_data"    => Agent::Tools::DeleteAppData
  }.freeze

  WORKSPACE_TOOLS = {
    "exec"               => Agent::Tools::Exec,
    "write_file"         => Agent::Tools::WriteFile,
    "read_file"          => Agent::Tools::ReadFile,
    "register_tool"      => Agent::Tools::RegisterTool,
    "unregister_tool"    => Agent::Tools::UnregisterTool,
    "list_custom_tools"  => Agent::Tools::ListCustomTools,
    "register_app"       => Agent::Tools::RegisterApp,
    "unregister_app"     => Agent::Tools::UnregisterApp
  }.freeze

  def self.definitions(agent:)
    tools = TOOLS.values
    tools += DATA_TOOLS.values if agent.accessible_apps.any?
    if agent.workspace_enabled?
      tools += WORKSPACE_TOOLS.values
      tools += agent.custom_tools.map { |ct| ct }
    end

    defs = tools.map(&:definition)

    agent.plugins.tool.each do |plugin|
      defs += plugin.tool_definitions
    end

    defs
  end

  def self.execute(name, arguments, agent:, context: {})
    if name.start_with?("custom_") && agent.workspace_enabled?
      custom_tool = agent.custom_tools.find_by(name: name.delete_prefix("custom_"))
      return "Unknown tool: #{name}" unless custom_tool

      result = Agent::Workspace.new(agent).exec(custom_tool.entrypoint, stdin: arguments.to_json)
      output = "#{result[:stdout]}#{result[:stderr]}".presence || "(no output)"
      return output.truncate(12_000, omission: "\n\n[Truncated]")
    end

    # Plugin tool dispatch
    plugin = agent.plugins.tool.detect { |p| p.tools.any? { |t| t["name"] == name } }
    if plugin
      return execute_plugin_tool(plugin, name, arguments, agent: agent, context: context)
    end

    tool_class = TOOLS[name] || DATA_TOOLS[name] || (agent.workspace_enabled? && WORKSPACE_TOOLS[name])
    return "Unknown tool: #{name}" unless tool_class

    tool_class.new(agent: agent, arguments: arguments, context: context).call
  rescue => e
    Rails.logger.error("Tool #{name} failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    "Tool error: #{e.message}"
  end

  def self.execute_plugin_tool(plugin, name, arguments, agent:, context: {})
    tool_schema = plugin.tools.find { |t| t["name"] == name }

    if tool_schema&.dig("async")
      return execute_plugin_tool_async(plugin, tool_schema, arguments, agent: agent, context: context)
    end

    if plugin.execution_sandbox?
      execute_plugin_in_sandbox(plugin, name, arguments, agent: agent)
    else
      execute_plugin_on_platform(plugin, name, arguments, agent: agent)
    end
  end

  def self.execute_plugin_tool_async(plugin, tool_schema, arguments, agent:, context: {})
    conversation = context[:conversation]
    return "Error: async plugin tool requires a conversation context" unless conversation

    command = plugin.build_tool_command(tool_schema, arguments, agent: agent)
    timeout = tool_schema["timeout"] || 600
    label = tool_schema["name"]

    workspace = Agent::Workspace.new(agent)
    workspace.exec_later(command, conversation: conversation, label: label, timeout: timeout)

    "#{label} started in the background. You'll receive the result when it completes."
  end

  def self.execute_plugin_in_sandbox(plugin, name, arguments, agent:)
    workspace = Agent::Workspace.new(agent)
    env_vars = plugin.resolved_env(agent: agent).map { |k, v| "#{k}=#{v}" }
    env_prefix = env_vars.any? ? "#{env_vars.map { |e| "export #{e}" }.join(" && ")} && " : ""

    entrypoint_path = File.join("/opt/plugins/#{plugin.name}", plugin.entrypoint)
    payload = { tool: name, arguments: arguments }.to_json

    result = workspace.exec("#{env_prefix}#{entrypoint_path}", stdin: payload)
    output = "#{result[:stdout]}#{result[:stderr]}".presence || "(no output)"
    output.truncate(12_000, omission: "\n\n[Truncated]")
  end

  def self.execute_plugin_on_platform(plugin, name, arguments, agent:)
    entrypoint_path = plugin.path.join(plugin.entrypoint)
    unless File.exist?(entrypoint_path)
      return "Plugin error: entrypoint not found at #{entrypoint_path}"
    end

    load entrypoint_path
    klass = plugin.name.classify.constantize
    klass.new(agent: agent).call(name, arguments)
  rescue => e
    "Plugin error: #{e.message}"
  end
end
