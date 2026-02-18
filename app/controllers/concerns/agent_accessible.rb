module AgentAccessible
  extend ActiveSupport::Concern

  private
    def accessible_agents
      Current.user.admin? ? Current.account.agents : Current.user.agents
    end
end
