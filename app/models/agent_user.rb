class AgentUser < ApplicationRecord
  belongs_to :agent
  belongs_to :user

  validates :user_id, uniqueness: { scope: :agent_id }
end
