require "test_helper"

class ScheduledActionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "validates reminder payload" do
    action = ScheduledAction.new(
      account: accounts(:one),
      agent: agents(:one),
      title: "Bad reminder",
      run_mode: "chat_trigger",
      schedule_kind: "once",
      timezone: "UTC",
      one_time_run_at: 1.hour.from_now,
      payload: {}
    )

    assert_not action.valid?
    assert_includes action.errors[:payload], "message is required for reminders"
  end

  test "computes next run for recurring schedule" do
    action = ScheduledAction.new(
      account: accounts(:one),
      agent: agents(:one),
      title: "Weekly",
      run_mode: "chat_trigger",
      payload: { "message" => "Ping" },
      timezone: "UTC"
    )

    action.apply_schedule(
      "kind" => "recurring",
      "rule" => {
        "frequency" => "weekly",
        "interval" => 1,
        "time_of_day" => "09:00",
        "days_of_week" => [ "mon", "wed" ]
      }
    )

    assert action.next_run_at.present?
    assert action.next_run_at > Time.current
  end

  test "dispatch_later enqueues dispatch job" do
    action = scheduled_actions(:one_time_reminder)

    assert_enqueued_with(job: ScheduledActionDispatchJob) do
      action.dispatch_later
    end
  end

  test "monthly recurrence skips invalid months" do
    action = ScheduledAction.new(
      account: accounts(:one),
      agent: agents(:one),
      title: "Month end",
      run_mode: "chat_trigger",
      schedule_kind: "recurring",
      payload: { "message" => "Ping" },
      timezone: "UTC",
      recurrence_rule: {
        "frequency" => "monthly",
        "interval" => 1,
        "time_of_day" => "09:00",
        "day_of_month" => 31
      }
    )

    reference = Time.utc(2026, 2, 1, 0, 0, 0)
    next_run = ScheduledAction::NextRunCalculation.new(action).next_run_at(reference_time: reference)

    assert_equal Time.utc(2026, 3, 31, 9, 0, 0), next_run
  end
end
