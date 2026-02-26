class Agent::Tools::RegisterApp < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "register_app",
        description: "Register a web app for users to access through AgentGridOS. Creates a mount at apps/{slug}/ in your workspace where you can write HTML/CSS/JS files.",
        parameters: {
          type: "object",
          properties: {
            slug: { type: "string", description: "App slug (lowercase letters, numbers, and hyphens, e.g. 'slideshow' or 'task-board')" },
            name: { type: "string", description: "Human-readable display name (defaults to titleized slug)" },
            description: { type: "string", description: "What the app does" },
            entrypoint: { type: "string", description: "Main HTML file within the app directory (default: 'index.html')" },
            icon_emoji: { type: "string", description: "Emoji to display as the app icon (e.g. '📊')" },
            icon_path: { type: "string", description: "Workspace-relative path to an icon image file" }
          },
          required: %w[slug description]
        }
      }
    }
  end

  def call
    slug = arguments["slug"]
    return "Error: slug is required" if slug.blank?
    return "Error: description is required" if arguments["description"].blank?

    custom_app = agent.custom_apps.find_or_initialize_by(slug: slug)
    is_new = custom_app.new_record?

    custom_app.assign_attributes(
      account: agent.account,
      name: arguments["name"].presence || slug.titleize,
      description: arguments["description"],
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
      write_agent_tools_template(custom_app) if is_new

      if is_new
        "Registered app '#{slug}'. Your workspace is restarting — the app directory is mounted at apps/#{slug}/. Write your HTML/CSS/JS files there. Users can access it at /apps/#{custom_app.id}."
      else
        "Updated app '#{slug}'. Files are at apps/#{slug}/ in your workspace. Users can access it at /apps/#{custom_app.id}."
      end
    else
      "Error: #{custom_app.errors.full_messages.join(", ")}"
    end
  end

  private
    def write_agent_tools_template(custom_app)
      path = custom_app.agent_tools_manifest_path
      return if path.exist?

      File.write(path, agent_tools_template)
    end

    def agent_tools_template
      <<~YAML
        version: 1
        tools:
          - name: add_item
            description: Add an item to your app data
            parameters:
              type: object
              properties:
                title:
                  type: string
              required: [title]
            behavior:
              kind: create
              table: items
              data:
                title: { arg: title }
      YAML
    end
end
