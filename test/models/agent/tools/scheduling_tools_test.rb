require "test_helper"

class Agent::Tools::SchedulingToolsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @agent = agents(:one)
    @chat = chats(:one)
    @user_message = messages(:one)
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "schedule_reminder creates scheduled action using sender timezone by default" do
    run_at = 2.hours.from_now.utc.iso8601

    result = call_tool(Agent::Tools::ScheduleReminder, {
      "title" => "Follow up",
      "message" => "Check deployment",
      "schedule" => { "kind" => "once", "run_at" => run_at }
    })

    assert_match /Scheduled reminder #\d+/, result

    action = @agent.scheduled_actions.order(:created_at).last
    assert_equal "chat_trigger", action.run_mode
    assert_equal "America/New_York", action.timezone
    assert_equal @chat.id, action.chat_id
    assert_equal "Check deployment", action.payload["message"]
    assert_enqueued_jobs 1, only: ScheduledActionDispatchJob
  end

  test "schedule_automation creates direct tool scheduled action" do
    run_at = 3.hours.from_now.utc.iso8601

    result = call_tool(Agent::Tools::ScheduleAutomation, {
      "title" => "List tools",
      "tool_name" => "list_custom_tools",
      "arguments" => {},
      "chat_id" => @chat.id,
      "schedule" => { "kind" => "once", "run_at" => run_at }
    })

    assert_match /Scheduled automation #\d+/, result

    action = @agent.scheduled_actions.order(:created_at).last
    assert_equal "direct_tool", action.run_mode
    assert_equal "list_custom_tools", action.payload["tool_name"]
    assert_equal({}, action.payload["arguments"])
    assert_equal @chat.id, action.payload["chat_id"]
  end

  test "list cancel and update scheduled actions" do
    action = scheduled_actions(:one_time_reminder)

    list_result = call_tool(Agent::Tools::ListScheduledActions, {})
    assert_includes list_result, "Follow up"

    update_result = call_tool(Agent::Tools::UpdateScheduledAction, {
      "id" => action.id,
      "title" => "Updated reminder",
      "message" => "Updated body"
    })
    assert_match /Updated scheduled action/, update_result

    action.reload
    assert_equal "Updated reminder", action.title
    assert_equal "Updated body", action.payload["message"]

    cancel_result = call_tool(Agent::Tools::CancelScheduledAction, { "id" => action.id })
    assert_match /Canceled scheduled action/, cancel_result

    action.reload
    assert action.canceled?
  end

  private
    def call_tool(klass, arguments, context_overrides = {})
      context = { chat: @chat, user_message_record: @user_message }.merge(context_overrides)
      klass.new(agent: @agent, arguments: arguments, context: context).call
    end
end
