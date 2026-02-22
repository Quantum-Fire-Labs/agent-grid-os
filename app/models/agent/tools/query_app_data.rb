class Agent::Tools::QueryAppData < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "query_app_data",
        description: "Query rows from a table in a custom app's database.",
        parameters: {
          type: "object",
          properties: {
            app: { type: "string", description: "Name of the custom app" },
            table: { type: "string", description: "Table name to query" },
            where: { type: "object", description: "Optional filter conditions as key-value pairs" },
            limit: { type: "integer", description: "Maximum rows to return (default 100, max 1000)" },
            offset: { type: "integer", description: "Number of rows to skip" }
          },
          required: %w[app table]
        }
      }
    }
  end

  def call
    app = find_app!
    return app if app.is_a?(String)

    rows = app.query(
      arguments["table"],
      where: arguments["where"],
      limit: arguments.fetch("limit", 100),
      offset: arguments.fetch("offset", 0)
    )

    return "No rows found." if rows.empty?

    "#{rows.size} row(s):\n#{rows.to_json}"
  end

  private
    def find_app!
      agent.accessible_apps.find_by!(name: arguments["app"])
    rescue ActiveRecord::RecordNotFound
      "Error: no app named '#{arguments["app"]}' found for this agent."
    end
end
