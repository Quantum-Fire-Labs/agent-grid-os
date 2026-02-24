module AgentAccessible
  extend ActiveSupport::Concern

  included do
    helper_method :can_admin_agent? if respond_to?(:helper_method)
  end

  private
    def accessible_agents
      Current.user.admin? ? Current.account.agents : Current.user.agents
    end

    def accessible_custom_apps
      if Current.user.admin?
        Current.account.custom_apps
      else
        Current.account.custom_apps.where(agent: Current.user.agents)
          .or(Current.account.custom_apps.where(id: Current.user.custom_app_ids))
      end
    end

    def can_admin_agent?(agent)
      return true if Current.user.admin?

      @_agent_admin_cache ||= {}
      @_agent_admin_cache.fetch(agent.id) do
        @_agent_admin_cache[agent.id] = agent.agent_users.count == 1 && agent.agent_users.exists?(user: Current.user)
      end
    end

    def require_agent_admin
      unless can_admin_agent?(@agent)
        redirect_back fallback_location: root_path, alert: "Only admins can access this."
      end
    end
end
