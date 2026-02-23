class Agent::Tools::DeleteAppData < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "delete_app_data",
        description: "Delete a row by ID from a table in a custom app's database.",
        parameters: {
          type: "object",
          properties: {
            app: { type: "string", description: "Slug of the custom app" },
            table: { type: "string", description: "Table name" },
            row_id: { type: "integer", description: "ID of the row to delete" }
          },
          required: %w[app table row_id]
        }
      }
    }
  end

  def call
    app = find_app!
    return app if app.is_a?(String)

    changes = app.delete_row(arguments["table"], arguments["row_id"])
    if changes > 0
      "Deleted row #{arguments["row_id"]} from '#{arguments["table"]}'."
    else
      "No row with id #{arguments["row_id"]} found in '#{arguments["table"]}'."
    end
  end

  private
    def find_app!
      agent.accessible_apps.find_by!(slug: arguments["app"])
    rescue ActiveRecord::RecordNotFound
      "Error: no app named '#{arguments["app"]}' found for this agent."
    end
end
