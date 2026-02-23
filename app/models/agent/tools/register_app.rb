class Agent::Tools::RegisterApp < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "register_app",
        description: "Register a web app built in your workspace for users to access through AgentGridOS. The app directory should contain an HTML entrypoint and any CSS/JS assets.",
        parameters: {
          type: "object",
          properties: {
            slug: { type: "string", description: "App slug (lowercase letters, numbers, and hyphens, e.g. 'slideshow' or 'task-board')" },
            name: { type: "string", description: "Human-readable display name (defaults to titleized slug)" },
            description: { type: "string", description: "What the app does" },
            path: { type: "string", description: "Workspace-relative path to the app directory (e.g. 'apps/slideshow')" },
            entrypoint: { type: "string", description: "Main HTML file within the app directory (default: 'index.html')" },
            icon_emoji: { type: "string", description: "Emoji to display as the app icon (e.g. '📊')" },
            icon_path: { type: "string", description: "Workspace-relative path to an icon image file" }
          },
          required: %w[slug description path]
        }
      }
    }
  end

  def call
    slug = arguments["slug"]
    return "Error: slug is required" if slug.blank?
    return "Error: description is required" if arguments["description"].blank?
    return "Error: path is required" if arguments["path"].blank?

    custom_app = agent.custom_apps.find_or_initialize_by(slug: slug)
    custom_app.assign_attributes(
      account: agent.account,
      name: arguments["name"].presence || slug.titleize,
      description: arguments["description"],
      path: arguments["path"],
      entrypoint: arguments["entrypoint"].presence || "index.html",
      icon_emoji: arguments["icon_emoji"]
    )

    if arguments["icon_path"].present?
      workspace = Agent::Workspace.new(agent)
      icon_full_path = workspace.path.join(arguments["icon_path"])
      if icon_full_path.exist?
        content_type = Marcel::MimeType.for(icon_full_path)
        custom_app.icon_image.attach(
          io: File.open(icon_full_path),
          filename: icon_full_path.basename.to_s,
          content_type: content_type
        )
      end
    end

    if custom_app.save
      "Registered app '#{slug}'. Users can access it at /apps/#{custom_app.id}."
    else
      "Error: #{custom_app.errors.full_messages.join(", ")}"
    end
  end
end
