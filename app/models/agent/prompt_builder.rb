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
    parts << skills_instructions if agent.skills.any?
    parts << plugin_instructions if agent.plugins.any?
    parts << orchestrator_context if agent.orchestrator?
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
      sections = agent.skills.map do |skill|
        "### #{skill.name}\n#{skill.body}"
      end

      "## Skills\n\n#{sections.join("\n\n")}"
    end

    def plugin_instructions
      sections = agent.plugins.filter_map do |plugin|
        next if plugin.provider_mode?(agent)
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

      parts << app_tools_instructions if agent.custom_apps.any? || agent.granted_apps.any?

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

    def app_tools_instructions
      <<~INSTRUCTIONS.strip
        ### App tools
        Apps can expose their own tools for domain-specific actions and data operations.
        Tool names are namespaced by app slug and look like `app_<slug>_<action>` (hyphens become underscores in the slug part).
        Prefer these app-specific tools over generic database-style operations.
      INSTRUCTIONS
    end

    def orchestrator_context
      <<~PROMPT.strip
        ## Orchestrator

        You are an orchestrator agent with the ability to manage other agents in this account. You have the following agent management tools:

        - `list_agents` — List all agents in the account with their name, title, status, and orchestrator flag
        - `get_agent` — Get full details of a specific agent by name
        - `create_agent` — Create a new agent with a name, title, description, personality, instructions, network mode, and workspace setting
        - `update_agent` — Update an existing agent's configuration by name

        Use these tools to inspect, create, and configure agents as needed. All agents you manage belong to the same account.
      PROMPT
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
