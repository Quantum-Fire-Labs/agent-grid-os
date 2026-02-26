class ScheduledActionRun < ApplicationRecord
  belongs_to :scheduled_action
  belongs_to :delivery_message, class_name: "Message", optional: true

  enum :status, %w[running succeeded failed canceled skipped].index_by(&:itself), default: "running"

  validates :scheduled_for_at, presence: true
  validates :started_at, presence: true
end
