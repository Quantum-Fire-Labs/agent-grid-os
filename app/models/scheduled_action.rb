class ScheduledAction < ApplicationRecord
  belongs_to :account
  belongs_to :agent
  belongs_to :chat, optional: true
  belongs_to :created_by_user, class_name: "User", optional: true
  belongs_to :created_from_message, class_name: "Message", optional: true

  has_many :runs, class_name: "ScheduledActionRun", dependent: :destroy

  enum :status, %w[active paused canceled completed].index_by(&:itself), default: "active"
  enum :run_mode, %w[chat_trigger direct_tool].index_by(&:itself)
  enum :schedule_kind, %w[once recurring].index_by(&:itself)
  enum :last_run_status, %w[succeeded failed].index_by(&:itself), prefix: true

  scope :upcoming, -> { where.not(next_run_at: nil).order(:next_run_at) }

  validates :title, presence: true
  validates :timezone, presence: true
  validate :timezone_must_be_valid
  validate :payload_must_match_run_mode
  validate :schedule_shape_must_be_valid

  def dispatch_later
    return if next_run_at.blank?

    ScheduledActionDispatchJob.set(wait_until: next_run_at).perform_later(self)
  end

  def dispatch_now
    with_lock do
      return if !active? || next_run_at.blank?

      if next_run_at > Time.current
        dispatch_later
        return
      end

      scheduled_for_at = next_run_at
      run = claim_run(scheduled_for_at)
      return unless run

      execute_occurrence_now(run)
      advance_after_run(run)
    end
  end

  def cancel
    return if canceled?

    update!(status: "canceled", canceled_at: Time.current, next_run_at: nil)
  end

  def apply_schedule(schedule_hash)
    schedule_hash = schedule_hash.deep_stringify_keys
    kind = schedule_hash["kind"].to_s

    self.schedule_kind = kind
    self.one_time_run_at = nil
    self.recurrence_rule = {}
    self.starts_at = nil
    self.ends_at = nil

    case kind
    when "once"
      self.one_time_run_at = parse_time!(schedule_hash["run_at"])
    when "recurring"
      self.recurrence_rule = schedule_hash.fetch("rule", {}).deep_stringify_keys
      self.starts_at = parse_time!(schedule_hash["starts_at"]) if schedule_hash["starts_at"].present?
      self.ends_at = parse_time!(schedule_hash["ends_at"]) if schedule_hash["ends_at"].present?
    else
      raise ArgumentError, "schedule.kind must be 'once' or 'recurring'"
    end

    recalculate_next_run_at
  rescue KeyError
    raise ArgumentError, "Invalid recurrence rule"
  end

  def recalculate_next_run_at(reference_time: Time.current)
    self.next_run_at = ScheduledAction::NextRunCalculation.new(self).next_run_at(reference_time: reference_time)
  end

  def reminder?
    chat_trigger?
  end

  def automation?
    direct_tool?
  end

  def summary_label
    reminder? ? "reminder" : "automation"
  end

  private
    def claim_run(scheduled_for_at)
      runs.create!(
        scheduled_for_at: scheduled_for_at,
        started_at: Time.current,
        status: "running"
      )
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def execute_occurrence_now(run)
      if chat_trigger?
        execute_reminder(run)
      else
        execute_automation(run)
      end
    rescue => e
      run.update!(
        status: "failed",
        error: e.message,
        finished_at: Time.current
      )
    end

    def execute_reminder(run)
      target_chat = resolved_chat_for_reminder
      raise "Reminder requires a chat" unless target_chat
      raise "Agent is no longer a participant in chat" unless target_chat.agents.exists?(id: agent_id)

      msg = target_chat.messages.create!(
        role: "system",
        content: "[Scheduled Reminder ##{id}: #{title}] #{payload.fetch("message")}"
      )

      target_chat.enqueue_agent_reply(agent: agent)

      run.update!(
        status: "succeeded",
        delivery_message: msg,
        result_summary: "Reminder delivered to chat ##{target_chat.id}",
        finished_at: Time.current
      )
    end

    def execute_automation(run)
      tool_name = payload.fetch("tool_name")
      tool_arguments = payload.fetch("arguments", {})
      target_chat = resolved_chat_for_automation

      result = Agent::ToolRegistry.execute(
        tool_name,
        tool_arguments,
        agent: agent,
        context: target_chat ? { chat: target_chat } : {}
      ).to_s

      delivered_message = post_automation_result(target_chat, tool_name, result) if target_chat

      run.update!(
        status: automation_result_failed?(result) ? "failed" : "succeeded",
        error: automation_result_failed?(result) ? result.truncate(1000) : nil,
        result_summary: result.truncate(4000),
        delivery_message: delivered_message,
        finished_at: Time.current
      )
    end

    def post_automation_result(target_chat, tool_name, result)
      tool_call_id = "call_scheduled_#{SecureRandom.hex(4)}"

      target_chat.messages.create!(
        role: "assistant",
        sender: agent,
        content: nil,
        tool_calls: [ { id: tool_call_id, type: "function", function: { name: tool_name, arguments: payload.fetch("arguments", {}).to_json } } ]
      )

      target_chat.messages.create!(
        role: "tool",
        tool_call_id: tool_call_id,
        content: "[scheduled automation #{automation_result_failed?(result) ? "failed" : "completed"}]\n\n#{result.truncate(12_000)}"
      )
    end

    def automation_result_failed?(result)
      result.start_with?("Error:", "Tool error:", "Unknown tool:") || result.match?(/\AExit code \d+:/)
    end

    def advance_after_run(run)
      attrs = {
        last_run_at: run.finished_at || Time.current,
        last_run_status: run.succeeded? ? "succeeded" : "failed",
        last_error: run.error
      }

      if once?
        update!(attrs.merge(status: "completed", next_run_at: nil))
        return
      end

      future_time = ScheduledAction::NextRunCalculation.new(self).next_run_at(reference_time: Time.current)
      attrs[:next_run_at] = future_time
      update!(attrs)
      dispatch_later if active? && next_run_at.present?
    end

    def resolved_chat_for_reminder
      chat
    end

    def resolved_chat_for_automation
      payload_chat_id = payload["chat_id"].presence
      return agent.account.chats.find_by(id: payload_chat_id) if payload_chat_id

      chat
    end

    def timezone_must_be_valid
      return if timezone.blank?
      return if ActiveSupport::TimeZone[timezone]

      errors.add(:timezone, "is invalid")
    end

    def payload_must_match_run_mode
      data = (payload || {}).deep_stringify_keys

      if chat_trigger?
        errors.add(:payload, "message is required for reminders") if data["message"].blank?
      elsif direct_tool?
        errors.add(:payload, "tool_name is required for automations") if data["tool_name"].blank?
        errors.add(:payload, "arguments must be an object") unless data["arguments"].is_a?(Hash)
      end
    end

    def schedule_shape_must_be_valid
      if once?
        errors.add(:one_time_run_at, "is required") if one_time_run_at.blank?
        return
      end

      return unless recurring?

      ScheduledAction::Recurrence.new(recurrence_rule).validate(errors)
      if starts_at.present? && ends_at.present? && ends_at < starts_at
        errors.add(:ends_at, "must be after starts_at")
      end
    end

    def parse_time!(value)
      return nil if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      raise ArgumentError, "Invalid timestamp: #{value}"
    end
end
