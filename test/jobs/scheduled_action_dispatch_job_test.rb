require "test_helper"

class ScheduledActionDispatchJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "dispatches reminder and enqueues agent reply" do
    action = scheduled_actions(:one_time_reminder)
    due_time = 5.minutes.ago
    action.update!(chat: chats(:one), one_time_run_at: due_time, next_run_at: due_time)

    assert_difference -> { chats(:one).messages.count }, 1 do
      assert_enqueued_with(job: Agent::ReplyJob) do
        ScheduledActionDispatchJob.perform_now(action)
      end
    end

    action.reload
    assert action.completed?
    assert_equal "succeeded", action.last_run_status
    assert action.runs.where(status: "succeeded").count >= 1
    assert_match /\[Scheduled Reminder ##{action.id}/, chats(:one).messages.order(:created_at).last.content
  end

  test "dispatches automation and writes tool result messages" do
    action = agent_one_time_automation

    assert_difference -> { chats(:one).messages.count }, 2 do
      ScheduledActionDispatchJob.perform_now(action)
    end

    action.reload
    run = action.runs.order(:created_at).last
    assert run.succeeded?
    assert action.completed?
    assert_equal "succeeded", action.last_run_status

    tool_message = chats(:one).messages.order(:created_at).last
    assert_equal "tool", tool_message.role
    assert_match /scheduled automation completed/i, tool_message.content
  end

  private
    def agent_one_time_automation
      due_time = 1.minute.ago
      ScheduledAction.create!(
        account: accounts(:one),
        agent: agents(:one),
        chat: chats(:one),
        title: "List tools later",
        status: "active",
        run_mode: "direct_tool",
        schedule_kind: "once",
        timezone: "UTC",
        one_time_run_at: due_time,
        next_run_at: due_time,
        recurrence_rule: {},
        payload: {
          "tool_name" => "list_skills",
          "arguments" => {},
          "chat_id" => chats(:one).id
        }
      )
    end
end
