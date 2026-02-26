class ScheduledActionDispatchJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(scheduled_action)
    scheduled_action.dispatch_now
  end
end
