module AgentAccessible
  extend ActiveSupport::Concern

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
end
