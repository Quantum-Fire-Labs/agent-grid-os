class Message < ApplicationRecord
  belongs_to :conversation, touch: true
  belongs_to :user, optional: true

  has_one_attached :audio

  validates :role, presence: true

  serialize :tool_calls, coder: JSON
end
