class Agent::Tools::InsertAppData < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "insert_app_data",
        description: "Insert a row into a table in a custom app's database.",
        parameters: {
          type: "object",
          properties: {
            app: { type: "string", description: "Name of the custom app" },
            table: { type: "string", description: "Table name to insert into" },
            data: { type: "object", description: "Column values as key-value pairs" }
          },
          required: %w[app table data]
        }
      }
    }
  end

  def call
    app = find_app!
    return app if app.is_a?(String)

    row_id = app.insert_row(arguments["table"], arguments["data"])
    "Inserted row with id #{row_id} into '#{arguments["table"]}'."
  end

  private
    def find_app!
      agent.accessible_apps.find_by!(name: arguments["app"])
    rescue ActiveRecord::RecordNotFound
      "Error: no app named '#{arguments["app"]}' found for this agent."
    end
end
