class CustomAppAgentAccess < ApplicationRecord
  belongs_to :agent
  belongs_to :custom_app

  validates :custom_app_id, uniqueness: { scope: :agent_id }
  validate :same_account

  after_create_commit :recreate_workspace
  after_destroy_commit :recreate_workspace

  private
    def same_account
      return if agent.blank? || custom_app.blank?
      errors.add(:base, "Agent and app must belong to the same account") unless agent.account_id == custom_app.account_id
    end

    def recreate_workspace
      return unless agent.workspace_enabled?

      workspace = Agent::Workspace.new(agent)
      return unless workspace.exists?

      workspace.destroy
      workspace.start
    end
end
