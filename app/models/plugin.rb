class Plugin < ApplicationRecord
  include Installable

  BUNDLED_DIR = Rails.root.join("lib", "plugins")

  belongs_to :account
  has_many :agent_plugins, dependent: :destroy
  has_many :agents, through: :agent_plugins
  has_many :plugin_configs, dependent: :destroy

  enum :plugin_type, %w[ tool channel ].index_by(&:itself)
  enum :execution, %w[ sandbox platform ].index_by(&:itself), prefix: true

  validates :name, presence: true,
    format: { with: /\A[a-z][a-z0-9_]{0,49}\z/, message: "must start with a letter and contain only lowercase letters, numbers, and underscores" },
    uniqueness: { scope: :account_id }
  validate :tool_names_unique, on: :create

  def self.bundled_manifests
    Dir.glob(BUNDLED_DIR.join("*/plugin.yaml")).map do |manifest_path|
      YAML.safe_load_file(manifest_path).merge("source_path" => File.dirname(manifest_path))
    end
  end

  def path
    Rails.root.join("storage", "plugins", id.to_s)
  end

  def tool_definitions
    tools.map do |tool|
      {
        type: "function",
        function: {
          name: tool["name"],
          description: tool["description"],
          parameters: tool["parameters"] || { type: "object", properties: {} }
        }
      }
    end
  end

  def build_tool_command(tool_schema, arguments, agent: nil)
    require "shellwords"

    command = tool_schema["command"].to_s.dup

    # Substitute {param} placeholders in the command template
    arguments.each do |key, value|
      next if value.is_a?(TrueClass) || value.is_a?(FalseClass)
      command.gsub!("{#{key}}", Shellwords.escape(value.to_s))
    end

    # Append conditional flags
    flags = tool_schema["flags"] || {}
    flags.each do |param, flag_template|
      value = arguments[param]
      next unless value.present?

      flag = flag_template.to_s.dup
      if flag.include?("{")
        flag.gsub!("{#{param}}", Shellwords.escape(value.to_s))
      end
      command << " #{flag}"
    end

    # Prepend env vars from plugin config
    env_vars = resolved_env(agent: agent)
    if env_vars.any?
      env_prefix = env_vars.map { |k, v| "export #{Shellwords.escape(k)}=#{Shellwords.escape(v)}" }.join(" && ")
      command = "#{env_prefix} && #{command}"
    end

    command
  end

  def required_domains
    network = permissions["network"]
    return [] if network == false || network.nil?
    return [] if network == true

    Array(network)
  end

  def requires_full_network?
    permissions["network"] == true
  end

  def resolve_config(key, agent:)
    agent_config = plugin_configs.find_by(configurable: agent, key: key)
    return agent_config.value if agent_config

    account_config = plugin_configs.find_by(configurable: account, key: key)
    account_config&.value
  end

  def resolved_env(agent:)
    config_schema.each_with_object({}) do |schema_entry, env|
      key = schema_entry["key"]
      value = resolve_config(key, agent: agent)
      env[key] = value if value.present?
    end
  end

  def instructions
    manifest_path = path.join("plugin.yaml")
    return nil unless manifest_path.exist?

    manifest = YAML.safe_load_file(manifest_path)
    manifest["instructions"]
  end

  def setup_command
    manifest_path = path.join("plugin.yaml")
    return nil unless manifest_path.exist?

    manifest = YAML.safe_load_file(manifest_path)
    manifest.dig("setup", "command")
  end

  def setup_instructions
    manifest_path = path.join("plugin.yaml")
    return nil unless manifest_path.exist?

    manifest = YAML.safe_load_file(manifest_path)
    manifest.dig("setup", "instructions")
  end

  def compatible_with_network_mode?(mode)
    return true if mode == "full"
    return true if permissions["network"] == false || permissions["network"].nil?
    return false if requires_full_network?

    %w[ allowed allowed_plus_skills ].include?(mode)
  end

  private
    def tool_names_unique
      tool_names = tools.map { |t| t["name"] }
      return if tool_names.empty?

      builtin_names = Agent::ToolRegistry::TOOLS.keys + Agent::ToolRegistry::WORKSPACE_TOOLS.keys
      conflicts = tool_names & builtin_names
      if conflicts.any?
        errors.add(:tools, "contain names that conflict with built-in tools: #{conflicts.join(", ")}")
      end

      other_plugin_tools = account&.plugins&.where&.not(id: id)&.flat_map { |p| p.tools.map { |t| t["name"] } } || []
      plugin_conflicts = tool_names & other_plugin_tools
      if plugin_conflicts.any?
        errors.add(:tools, "contain names that conflict with other plugins: #{plugin_conflicts.join(", ")}")
      end
    end
end
