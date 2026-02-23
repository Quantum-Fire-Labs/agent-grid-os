class Participant < ApplicationRecord
  scope :users_only, -> { where(participatable_type: "User") }
  scope :agents_only, -> { where(participatable_type: "Agent") }

  belongs_to :chat
  belongs_to :participatable, polymorphic: true, optional: true
end
