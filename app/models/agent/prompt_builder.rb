class Agent::PromptBuilder
  attr_reader :agent

  def initialize(agent)
    @agent = agent
  end

  def system_prompt(chat: nil, current_message: nil, current_message_record: nil)
    parts = []
    parts << identity
    parts << personality if agent.personality.present?
    parts << instructions if agent.instructions.present?
    parts << network_access if agent.workspace_enabled?
    parts << skills_instructions if agent.respond_to?(:skills) && agent.account.skills.any?
    parts << plugin_instructions if agent.plugins.any?
    parts << apps_context if agent.workspace_enabled? || agent.custom_apps.any? || agent.granted_apps.any?
    parts << recalled_memories(chat, current_message)
    parts << group_chat_context(chat) if chat&.group?
    parts << current_time(current_message_record)
    parts.compact.join("\n\n")
  end

  private

    def identity
      "You are #{agent.name}." \
      "#{" #{agent.title}." if agent.title.present?}" \
      "#{" #{agent.description}" if agent.description.present?}"
    end

    def personality
      "## Personality\n\n#{agent.personality}"
    end

    def instructions
      "## Instructions\n\n#{agent.instructions}"
    end

    def network_access
      case agent.network_mode
      when "none"
        "## Network Access\n\nYou have no network access. You cannot make outbound HTTP requests."
      when "allowed"
        "## Network Access\n\nYou have network access. You can make outbound HTTP requests to external services."
      when "allowed_plus_skills"
        "## Network Access\n\nYou have network access with skill-specific permissions. You can make outbound HTTP requests."
      when "full"
        "## Network Access\n\nYou have full network access. You can make HTTP requests to external services."
      end
    end

    def skills_instructions
      enabled_skills = agent.account.skills
      return if enabled_skills.none?

      sections = enabled_skills.map do |skill|
        "### #{skill.name}\n#{skill.body}" if skill.body.present?
      end.compact

      "## Skills\n\n#{sections.join("\n\n")}" if sections.any?
    end

    def plugin_instructions
      sections = agent.plugins.filter_map do |plugin|
        body = plugin.instructions
        "### #{plugin.name}\n#{body}" if body.present?
      end

      "## Plugins\n\n#{sections.join("\n\n")}" if sections.any?
    end

    def group_chat_context(chat)
      names = chat.users.pluck(:first_name).join(", ")
      "## Group Chat\n\nThis is a group chat with multiple participants: #{names}. " \
      "User messages are prefixed with [Name] to indicate the sender. " \
      "Use @Name mentions when addressing or referring to specific participants (e.g. @#{chat.users.first&.first_name})."
    end

    def current_time(message)
      sender_user = (message&.sender if message&.sender.is_a?(User))
      tz = sender_user&.time_zone
      time = tz.present? ? Time.current.in_time_zone(tz) : Time.current
      "Current time: #{time.strftime("%A, %B %-d, %Y at %-I:%M %p %Z")}"
    end

    def apps_context
      parts = []

      if agent.workspace_enabled?
        parts << apps_instructions
      end

      parts << data_tools_instructions if agent.custom_apps.any? || agent.granted_apps.any?

      apps = agent.custom_apps.order(:slug)
      if apps.any?
        lines = apps.map { |app| "- #{app.slug} (#{app.status}): #{app.description}" }
        parts << "### Your registered apps\n#{lines.join("\n")}"
      end

      granted = agent.granted_apps.where(status: :published).order(:slug)
      if granted.any?
        lines = granted.map { |app| "- #{app.slug}: #{app.description}" }
        parts << "### Apps you have data access to\n#{lines.join("\n")}"
      end

      parts.compact.any? ? "## Apps\n\n#{parts.compact.join("\n\n")}" : nil
    end

    def apps_instructions
      <<~INSTRUCTIONS.strip
        You can build web apps and serve them to users through AgentGridOS. Call `register_app` first to create the app — this makes `apps/{slug}/` available in your workspace. Then write your HTML/CSS/JS files there.

        ### How it works
        - Call `register_app` with a slug and description to create the app
        - This mounts a directory at `apps/{slug}/` in your workspace where you write your files
        - Create an `index.html` entrypoint in that directory
        - Additional JS, CSS, and image files in that directory are served via `/apps/:id/assets/...`
        - The app renders inside AgentGridOS's layout with the nav bar above it
        - **Important:** Do NOT include `<!DOCTYPE>`, `<html>`, `<head>`, or `<body>` tags — your HTML is injected into the existing page. Just write the content directly (styles, scripts, and markup)
        - Wrap your app in a container div (e.g. `<div id="app">`) and scope all CSS under it (e.g. `#app h1 { ... }`) to avoid conflicts with AgentGridOS's styles

        ### JavaScript SDK
        Every app automatically gets `window.AgentGridOS` which provides:

        **App & user info:**
        - `AgentGridOS.app.id`, `AgentGridOS.app.name`
        - `AgentGridOS.user.id`, `AgentGridOS.user.name`

        **Relational database** (each app gets its own persistent SQLite database):
        - `await AgentGridOS.db.createTable(name, columns)` — columns: `[{name: "title", type: "TEXT"}, {name: "count", type: "INTEGER"}]`
        - `await AgentGridOS.db.listTables()`
        - `await AgentGridOS.db.dropTable(name)`
        - `await AgentGridOS.db.insert(table, {col: value, ...})` — returns `{id}`
        - `await AgentGridOS.db.query(table, {where: {col: value}, limit: 100, offset: 0})` — returns rows
        - `await AgentGridOS.db.get(table, rowId)` — returns single row
        - `await AgentGridOS.db.update(table, rowId, {col: newValue})`
        - `await AgentGridOS.db.delete(table, rowId)`

        **Key-value store** (convenience wrapper over the database):
        - `await AgentGridOS.kv.set(namespace, key, value)` — value is JSON-serialized
        - `await AgentGridOS.kv.get(namespace, key)` — returns parsed value or null
        - `await AgentGridOS.kv.list(namespace)` — returns `[{key, value}, ...]`
        - `await AgentGridOS.kv.delete(namespace, key)`

        ### Tips
        - Use inline `<script>` and `<style>` tags for simple apps, or reference separate files via relative paths
        - The CSRF token is handled automatically by the SDK
        - All SDK methods are async and return promises
        - Column types: TEXT, INTEGER, REAL, BLOB, NUMERIC
      INSTRUCTIONS
    end

    def data_tools_instructions
      <<~INSTRUCTIONS.strip
        ### App data tools
        You can read and write app data directly during chat:
        - `list_app_tables` — list all tables in an app's database
        - `query_app_data` — query rows from a table (supports `where`, `limit`, `offset`)
        - `insert_app_data` — insert a row into a table
        - `update_app_data` — update a row by ID
        - `delete_app_data` — delete a row by ID

        All data tools take an `app` parameter (the app slug) to identify which app's database to use.
      INSTRUCTIONS
    end

    def recalled_memories(chat, current_message)
      return unless chat && current_message

      recall = Agent::MemoryRecall.new(agent)
      seed = recall.build_seed(chat, current_message)
      results = recall.recall(seed)
      return if results.blank?

      formatted = recall.format_memories(results)
      "## Recalled Memories\n\n#{formatted}"
    end
end
