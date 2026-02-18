class Agent::Tools::UnregisterApp < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "unregister_app",
        description: "Remove a previously registered app.",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "The app name to remove" }
          },
          required: [ "name" ]
        }
      }
    }
  end

  def call
    name = arguments["name"]
    return "Error: name is required" if name.blank?

    custom_app = agent.custom_apps.find_by(name: name)
    return "Error: no app named '#{name}'" unless custom_app

    FileUtils.rm_f(custom_app.database_path)
    custom_app.destroy!
    "Unregistered app '#{name}'."
  end
end
