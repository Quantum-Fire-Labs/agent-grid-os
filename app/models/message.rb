class Message < ApplicationRecord
  belongs_to :chat, optional: true, touch: true
  belongs_to :sender, polymorphic: true, optional: true

  has_one_attached :audio

  validates :role, presence: true

  serialize :tool_calls, coder: JSON
end
