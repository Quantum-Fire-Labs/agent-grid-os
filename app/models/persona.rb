class Persona
  BUNDLED_DIR = Rails.root.join("lib", "personas")

  class NotFound < StandardError; end

  attr_reader :name, :title, :description, :personality, :instructions,
              :network_mode, :workspace_enabled, :recommended_plugins,
              :recommended_settings, :version

  class << self
    def all
      Dir.glob(BUNDLED_DIR.join("*/persona.yaml")).map do |path|
        new(YAML.safe_load_file(path))
      end
    end

    def find(name)
      path = BUNDLED_DIR.join(name, "persona.yaml")
      raise NotFound, "Persona '#{name}' not found" unless path.exist?
      new(YAML.safe_load_file(path))
    end
  end

  def initialize(data)
    @name = data["name"]
    @title = data["title"]
    @description = data["description"]
    @personality = data["personality"]
    @instructions = data["instructions"]
    @network_mode = data["network_mode"] || "none"
    @workspace_enabled = data["workspace_enabled"] || false
    @recommended_plugins = data["recommended_plugins"] || []
    @recommended_settings = data["recommended_settings"] || {}
    @version = data["version"]
  end

  def agent_attributes
    {
      title: title,
      description: description,
      personality: personality,
      instructions: instructions,
      network_mode: network_mode,
      workspace_enabled: workspace_enabled
    }
  end
end
