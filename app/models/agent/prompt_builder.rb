class Agent::PromptBuilder
  attr_reader :agent

  def initialize(agent)
    @agent = agent
  end

  def system_prompt(conversation: nil, current_message: nil)
    parts = []
    parts << identity
    parts << personality if agent.personality.present?
    parts << skills_instructions if agent.respond_to?(:skills) && agent.account.skills.any?
    parts << plugin_instructions if agent.plugins.any?
    parts << recalled_memories(conversation, current_message)
    parts << group_chat_context(conversation) if conversation&.kind_group?
    parts << current_time
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

    def group_chat_context(conversation)
      names = conversation.users.pluck(:first_name).join(", ")
      "## Group Chat\n\nThis is a group conversation with multiple participants: #{names}. " \
      "User messages are prefixed with [Name] to indicate the sender. " \
      "Use @Name mentions when addressing or referring to specific participants (e.g. @#{conversation.users.first&.first_name})."
    end

    def current_time
      "Current time: #{Time.current.strftime("%A, %B %-d, %Y at %-I:%M %p %Z")}"
    end

    def recalled_memories(conversation, current_message)
      return unless conversation && current_message

      recall = Agent::MemoryRecall.new(agent)
      seed = recall.build_seed(conversation, current_message)
      results = recall.recall(seed)
      return if results.blank?

      formatted = recall.format_memories(results)
      "## Recalled Memories\n\n#{formatted}"
    end
end
