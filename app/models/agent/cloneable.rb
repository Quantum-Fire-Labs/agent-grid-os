module Agent::Cloneable
  extend ActiveSupport::Concern

  def duplicate(name:, include_memories: false)
    transaction do
      clone = account.agents.create!(cloned_attributes.merge(name: name))
      duplicate_agent_models(clone)
      duplicate_agent_plugins(clone)
      duplicate_custom_tools(clone)
      duplicate_key_chains(clone)
      duplicate_memories(clone) if include_memories
      clone
    end
  end

  private
    def cloned_attributes
      slice(:personality, :instructions, :network_mode,
            :workspace_enabled, :title, :description, :orchestrator)
    end

    def duplicate_agent_models(clone)
      agent_models.find_each do |am|
        existing = clone.agent_models.find_by(provider: am.provider)
        if existing
          existing.update!(model: am.model, designation: am.designation)
        else
          clone.agent_models.create!(
            provider: am.provider,
            model: am.model,
            designation: am.designation
          )
        end
      end
    end

    def duplicate_agent_plugins(clone)
      agent_plugins.find_each do |ap|
        clone.agent_plugins.create!(plugin: ap.plugin)
      end
    end

    def duplicate_custom_tools(clone)
      custom_tools.find_each do |ct|
        clone.custom_tools.create!(
          name: ct.name,
          description: ct.description,
          entrypoint: ct.entrypoint,
          parameter_schema: ct.parameter_schema
        )
      end
    end

    def duplicate_key_chains(clone)
      key_chains.find_each do |kc|
        clone.key_chains.create!(
          name: kc.name,
          secrets: kc.secrets,
          sandbox_accessible: kc.sandbox_accessible
        )
      end
    end

    def duplicate_memories(clone)
      memories.find_each do |memory|
        clone.memories.create!(
          content: memory.content,
          state: memory.state
        )
      end
    end
end
