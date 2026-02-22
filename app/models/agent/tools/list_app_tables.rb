class Agent::Tools::ListAppTables < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "list_app_tables",
        description: "List all tables in a custom app's database.",
        parameters: {
          type: "object",
          properties: {
            app: { type: "string", description: "Name of the custom app" }
          },
          required: %w[app]
        }
      }
    }
  end

  def call
    app = find_app!
    return app if app.is_a?(String)

    tables = app.list_tables
    return "No tables found in '#{arguments["app"]}'." if tables.empty?

    "Tables in '#{arguments["app"]}':\n#{tables.map { |t| "- #{t}" }.join("\n")}"
  end

  private
    def find_app!
      agent.accessible_apps.find_by!(name: arguments["app"])
    rescue ActiveRecord::RecordNotFound
      "Error: no app named '#{arguments["app"]}' found for this agent."
    end
end
