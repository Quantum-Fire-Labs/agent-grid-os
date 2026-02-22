class Agent::Tools::UpdateAppData < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "update_app_data",
        description: "Update a row by ID in a table in a custom app's database.",
        parameters: {
          type: "object",
          properties: {
            app: { type: "string", description: "Name of the custom app" },
            table: { type: "string", description: "Table name" },
            row_id: { type: "integer", description: "ID of the row to update" },
            data: { type: "object", description: "Column values to update as key-value pairs" }
          },
          required: %w[app table row_id data]
        }
      }
    }
  end

  def call
    app = find_app!
    return app if app.is_a?(String)

    changes = app.update_row(arguments["table"], arguments["row_id"], arguments["data"])
    if changes > 0
      "Updated #{changes} row(s) in '#{arguments["table"]}'."
    else
      "No row with id #{arguments["row_id"]} found in '#{arguments["table"]}'."
    end
  end

  private
    def find_app!
      agent.custom_apps.find_by!(name: arguments["app"])
    rescue ActiveRecord::RecordNotFound
      "Error: no app named '#{arguments["app"]}' found for this agent."
    end
end
