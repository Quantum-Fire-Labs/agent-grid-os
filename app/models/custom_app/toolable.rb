require "yaml"

module CustomApp::Toolable
  extend ActiveSupport::Concern

  MANIFEST_FILE = "agent_tools.yml"
  MAX_TOOLS = 20
  MAX_WORKFLOW_STEPS = 25
  MAX_QUERY_LIMIT = 1000
  DEFAULT_QUERY_LIMIT = 100

  def agent_tool_prefix
    "app_#{slug.tr("-", "_")}_"
  end

  def agent_tools_manifest_path
    files_path.join(MANIFEST_FILE)
  end

  def agent_tools_manifest
    @agent_tools_manifest ||= load_agent_tools_manifest
  end

  def agent_tool_definitions
    manifest = agent_tools_manifest
    return [] unless manifest["tools"].present?

    manifest["tools"].map do |tool|
      {
        type: "function",
        function: {
          name: "#{agent_tool_prefix}#{tool.fetch("name")}",
          description: tool.fetch("description"),
          parameters: tool.fetch("parameters")
        }
      }
    end
  rescue AgentToolError
    []
  end

  def agent_tool_definition(action_name)
    agent_tools_manifest.fetch("tools").find { |tool| tool["name"] == action_name }
  end

  def call_agent_tool(action_name, arguments:, agent:)
    unless agent.accessible_apps.exists?(id: id)
      return tool_response(
        tool: "#{agent_tool_prefix}#{action_name}",
        error: { code: "unknown_app", message: "App '#{slug}' is not accessible to this agent." }
      )
    end

    tool = agent_tool_definition(action_name)
    unless tool
      return tool_response(
        tool: "#{agent_tool_prefix}#{action_name}",
        error: { code: "unknown_tool", message: "Tool '#{action_name}' is not defined for app '#{slug}'." }
      )
    end

    validate_tool_arguments!(arguments, tool.fetch("parameters"))
    result = run_behavior!(tool.fetch("behavior"), arguments)

    tool_response(tool: "#{agent_tool_prefix}#{action_name}", result: result)
  rescue AgentToolError => e
    tool_response(tool: "#{agent_tool_prefix}#{action_name}", error: e.to_h, hints: e.hints)
  rescue SQLite3::Exception => e
    tool_response(
      tool: "#{agent_tool_prefix}#{action_name}",
      error: { code: "execution_failed", message: e.message }
    )
  rescue => e
    tool_response(
      tool: "#{agent_tool_prefix}#{action_name}",
      error: { code: "execution_failed", message: e.message }
    )
  end

  private
    AgentToolError = Class.new(StandardError) do
      attr_reader :code, :details, :hints

      def initialize(code, message, details: nil, hints: nil)
        super(message)
        @code = code
        @details = details
        @hints = hints
      end

      def to_h
        {
          code: code,
          message: message,
          details: details
        }.compact
      end
    end

    def load_agent_tools_manifest
      unless agent_tools_manifest_path.exist?
        raise AgentToolError.new("manifest_missing", "No #{MANIFEST_FILE} found for app '#{slug}'.")
      end

      raw = YAML.safe_load(agent_tools_manifest_path.read, permitted_classes: [], aliases: false)
      validate_manifest!(raw)
    rescue Psych::Exception => e
      raise AgentToolError.new("manifest_invalid", "Invalid #{MANIFEST_FILE}: #{e.message}")
    end

    def validate_manifest!(raw)
      raise AgentToolError.new("manifest_invalid", "Manifest must be an object.") unless raw.is_a?(Hash)
      raise AgentToolError.new("manifest_invalid", "Manifest version must be 1.") unless raw["version"] == 1

      tools = raw["tools"]
      raise AgentToolError.new("manifest_invalid", "Manifest tools must be an array.") unless tools.is_a?(Array)
      raise AgentToolError.new("manifest_invalid", "Manifest can define at most #{MAX_TOOLS} tools.") if tools.size > MAX_TOOLS

      seen_names = []
      normalized_tools = tools.map do |tool|
        validate_manifest_tool!(tool, seen_names)
      end

      { "version" => 1, "tools" => normalized_tools }
    end

    def validate_manifest_tool!(tool, seen_names)
      raise AgentToolError.new("manifest_invalid", "Tool entry must be an object.") unless tool.is_a?(Hash)

      name = tool["name"].to_s
      unless name.match?(/\A[a-z][a-z0-9_]{0,49}\z/)
        raise AgentToolError.new("manifest_invalid", "Invalid tool name '#{name}'.")
      end

      if seen_names.include?(name)
        raise AgentToolError.new("manifest_invalid", "Duplicate tool name '#{name}'.")
      end
      seen_names << name

      description = tool["description"].to_s
      raise AgentToolError.new("manifest_invalid", "Tool '#{name}' is missing description.") if description.blank?

      parameters = normalize_parameters_schema(tool["parameters"], name:)
      behavior = normalize_behavior(tool["behavior"], name:)

      {
        "name" => name,
        "description" => description,
        "parameters" => parameters,
        "behavior" => behavior
      }
    end

    def normalize_parameters_schema(schema, name:)
      raise AgentToolError.new("manifest_invalid", "Tool '#{name}' parameters must be an object schema.") unless schema.is_a?(Hash)
      raise AgentToolError.new("manifest_invalid", "Tool '#{name}' parameters.type must be 'object'.") unless schema["type"] == "object"

      properties = schema["properties"]
      raise AgentToolError.new("manifest_invalid", "Tool '#{name}' parameters.properties must be an object.") unless properties.is_a?(Hash)

      required = Array(schema["required"]).map(&:to_s)

      {
        "type" => "object",
        "properties" => properties.deep_stringify_keys,
        "required" => required
      }
    end

    def normalize_behavior(behavior, name:)
      raise AgentToolError.new("manifest_invalid", "Tool '#{name}' behavior must be an object.") unless behavior.is_a?(Hash)

      normalized = behavior.deep_stringify_keys
      kind = normalized["kind"].to_s
      allowed = %w[inspect find fetch create change remove save workflow]
      unless allowed.include?(kind)
        raise AgentToolError.new("manifest_invalid", "Tool '#{name}' behavior.kind '#{kind}' is not supported.")
      end

      if kind == "workflow"
        steps = normalized["steps"]
        raise AgentToolError.new("manifest_invalid", "Tool '#{name}' workflow.steps must be an array.") unless steps.is_a?(Array)
        raise AgentToolError.new("manifest_invalid", "Tool '#{name}' workflow has too many steps.") if steps.size > MAX_WORKFLOW_STEPS
        normalized["steps"] = steps.map { |step| normalize_behavior(step, name:) }
      end

      normalized
    end

    def validate_tool_arguments!(arguments, schema)
      unless arguments.is_a?(Hash)
        raise AgentToolError.new("invalid_arguments", "Tool arguments must be an object.")
      end

      properties = schema.fetch("properties")
      required = schema.fetch("required", [])

      missing = required.reject { |key| arguments.key?(key) }
      if missing.any?
        raise AgentToolError.new("invalid_arguments", "Missing required arguments: #{missing.join(", ")}.")
      end

      arguments.each do |key, value|
        next unless properties.key?(key)

        expected_type = properties.dig(key, "type")
        next unless expected_type.present?
        next if value.nil?
        next if argument_type_valid?(value, expected_type)

        raise AgentToolError.new(
          "invalid_arguments",
          "Argument '#{key}' must be #{expected_type}.",
          details: { argument: key, expected_type: expected_type, actual_class: value.class.name }
        )
      end
    end

    def argument_type_valid?(value, expected_type)
      case expected_type
      when "string" then value.is_a?(String)
      when "integer" then value.is_a?(Integer)
      when "number" then value.is_a?(Numeric)
      when "boolean" then value == true || value == false
      when "object" then value.is_a?(Hash)
      when "array" then value.is_a?(Array)
      else true
      end
    end

    def run_behavior!(behavior, arguments)
      case behavior.fetch("kind")
      when "inspect" then inspect_behavior
      when "find" then find_behavior(behavior, arguments)
      when "fetch" then fetch_behavior(behavior, arguments)
      when "create" then create_behavior(behavior, arguments)
      when "change" then change_behavior(behavior, arguments)
      when "remove" then remove_behavior(behavior, arguments)
      when "save" then save_behavior(behavior, arguments)
      when "workflow" then workflow_behavior(behavior, arguments)
      else
        raise AgentToolError.new("operation_not_allowed", "Unsupported behavior kind '#{behavior["kind"]}'.")
      end
    rescue SQLite3::SQLException => e
      raise map_sqlite_error(e)
    rescue ArgumentError => e
      if e.message.match?(/row limit exceeded/i)
        raise AgentToolError.new("row_limit_exceeded", e.message)
      end

      raise AgentToolError.new("execution_failed", e.message)
    end

    def inspect_behavior
      { tables: tables_schema }
    end

    def find_behavior(behavior, arguments)
      limit = resolved_limit(behavior, arguments)
      {
        rows: query(
          resolve_template_value(behavior.fetch("table"), arguments),
          where: compact_hash(resolve_template_value(behavior["where"], arguments)),
          limit: limit,
          offset: resolve_template_value(behavior["offset"], arguments) || 0,
          order: resolve_template_value(behavior["order"], arguments),
          select: resolve_template_value(behavior["select"], arguments)
        )
      }
    end

    def fetch_behavior(behavior, arguments)
      table = resolve_template_value(behavior.fetch("table"), arguments)
      if behavior.key?("id")
        row = get_row(table, resolve_template_value(behavior["id"], arguments))
      else
        where = compact_hash(resolve_template_value(behavior["where"], arguments))
        row = query(table, where: where, limit: 1, offset: 0).first
      end

      raise AgentToolError.new("row_not_found", "No row found.") if row.blank?

      { row: row }
    end

    def create_behavior(behavior, arguments)
      table = resolve_template_value(behavior.fetch("table"), arguments)
      data = resolve_template_value(behavior.fetch("data"), arguments)
      row_id = insert_row(table, data)
      { id: row_id, row: get_row(table, row_id) }
    end

    def change_behavior(behavior, arguments)
      table = resolve_template_value(behavior.fetch("table"), arguments)
      data = resolve_template_value(behavior.fetch("data"), arguments)

      if behavior.key?("id")
        row_id = resolve_template_value(behavior["id"], arguments)
        changes = update_row(table, row_id, data)
        raise AgentToolError.new("row_not_found", "No row with id #{row_id}.") if changes == 0
        { changed: changes, row: get_row(table, row_id) }
      else
        where = compact_hash(resolve_template_value(behavior["where"], arguments))
        max_rows = resolve_template_value(behavior["max_rows"], arguments)
        changes = update_rows(table, where:, data:, max_rows:)
        { changed: changes }
      end
    end

    def remove_behavior(behavior, arguments)
      table = resolve_template_value(behavior.fetch("table"), arguments)

      if behavior.key?("id")
        row_id = resolve_template_value(behavior["id"], arguments)
        changes = delete_row(table, row_id)
        raise AgentToolError.new("row_not_found", "No row with id #{row_id}.") if changes == 0
        { removed: changes, id: row_id }
      else
        where = compact_hash(resolve_template_value(behavior["where"], arguments))
        max_rows = resolve_template_value(behavior["max_rows"], arguments)
        changes = delete_rows(table, where:, max_rows:)
        { removed: changes }
      end
    end

    def save_behavior(behavior, arguments)
      table = resolve_template_value(behavior.fetch("table"), arguments)
      match = compact_hash(resolve_template_value(behavior.fetch("match"), arguments))
      data = resolve_template_value(behavior.fetch("data"), arguments)
      result = save_row(table, match:, data:)
      { action: result[:action], id: result[:id], row: get_row(table, result[:id]) }
    end

    def workflow_behavior(behavior, arguments)
      steps = []
      with_transaction do
        behavior.fetch("steps").each do |step|
          steps << run_behavior!(step, arguments)
        end
      end
      { steps: steps }
    end

    def resolved_limit(behavior, arguments)
      raw = if behavior.key?("limit")
        resolve_template_value(behavior["limit"], arguments)
      else
        DEFAULT_QUERY_LIMIT
      end

      raw.to_i.clamp(1, MAX_QUERY_LIMIT)
    end

    def resolve_template_value(template, arguments)
      case template
      when nil
        nil
      when Hash
        if template.keys == [ "arg" ] || template.keys == [ :arg ]
          arguments[template["arg"] || template[:arg]]
        else
          template.each_with_object({}) do |(key, value), out|
            out[key.to_s] = resolve_template_value(value, arguments)
          end
        end
      when Array
        template.map { |value| resolve_template_value(value, arguments) }
      else
        template
      end
    end

    def compact_hash(value)
      return value unless value.is_a?(Hash)
      value.compact
    end

    def tool_response(tool:, result: nil, error: nil, hints: nil)
      {
        ok: error.nil?,
        tool: tool,
        app: slug,
        result: result,
        error: error,
        hints: hints
      }.compact.to_json
    end

    def map_sqlite_error(error)
      message = error.message.to_s

      if message.match?(/no such table/i)
        AgentToolError.new("unknown_table", message)
      elsif message.match?(/no such column/i)
        AgentToolError.new("unknown_column", message)
      else
        AgentToolError.new("execution_failed", message)
      end
    end
end
