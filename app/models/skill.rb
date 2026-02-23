class Skill < ApplicationRecord
  belongs_to :account
  has_many :agent_skills, dependent: :destroy
  has_many :agents, through: :agent_skills

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :body, presence: true
end
