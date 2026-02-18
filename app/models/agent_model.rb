class AgentModel < ApplicationRecord
  belongs_to :agent
  belongs_to :provider

  enum :designation, %w[default fallback].index_by(&:itself), default: "fallback", prefix: true

  validates :model, presence: true
  validates :provider_id, uniqueness: { scope: :agent_id }
  validate :provider_belongs_to_same_account

  before_save :demote_existing_default, if: :designation_default?

  private
    def demote_existing_default
      AgentModel.where(agent: agent)
                .where(designation: :default)
                .where.not(id: id)
                .update_all(designation: :fallback)
    end

    def provider_belongs_to_same_account
      return unless agent && provider

      if provider.account_id != agent.account_id
        errors.add(:provider, "must belong to the same account as the agent")
      end
    end
end
