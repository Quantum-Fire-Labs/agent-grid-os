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
            slug: { type: "string", description: "The app slug to remove" }
          },
          required: [ "slug" ]
        }
      }
    }
  end

  def call
    slug = arguments["slug"]
    return "Error: slug is required" if slug.blank?

    custom_app = agent.custom_apps.find_by(slug: slug)
    return "Error: no app with slug '#{slug}'" unless custom_app

    custom_app.destroy!
    "Unregistered app '#{slug}'. Your workspace is restarting to remove the mount."
  end
end
