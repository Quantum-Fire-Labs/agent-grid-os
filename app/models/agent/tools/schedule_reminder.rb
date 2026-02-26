class Agent::Tools::ScheduleReminder < Agent::Tools::Base
  include Agent::Tools::SchedulingParams

  def self.definition
    {
      type: "function",
      function: {
        name: "schedule_reminder",
        description: "Schedule a reminder or follow-up message for later. This posts a scheduled reminder into the chat and lets you handle it at runtime.",
        parameters: {
          type: "object",
          properties: {
            title: { type: "string", description: "Short reminder title" },
            message: { type: "string", description: "Reminder text or deferred instruction" },
            timezone: { type: "string", description: "IANA timezone (optional; defaults to the user's timezone when available)" },
            chat_id: { type: "integer", description: "Target chat ID (optional; defaults to current chat)" },
            schedule: {
              type: "object",
              description: "When to run. Use {kind:'once', run_at:'RFC3339'} or {kind:'recurring', rule:{...}}."
            }
          },
          required: %w[title message schedule]
        }
      }
    }
  end

  def call
    return "Error: title is required" if arguments["title"].blank?
    return "Error: message is required" if arguments["message"].blank?

    tz = effective_timezone(arguments["timezone"])
    chat = resolve_chat(arguments["chat_id"])
    return "Error: reminder requires a chat context" unless chat

    action = agent.account.scheduled_actions.new(
      agent: agent,
      chat: chat,
      created_by_user: scheduling_user,
      created_from_message: context[:user_message_record],
      title: arguments["title"],
      run_mode: "chat_trigger",
      payload: { "message" => arguments["message"] },
      timezone: tz
    )

    parse_schedule!(action, timezone: tz)
    action.save!
    action.dispatch_later

    "Scheduled reminder ##{action.id} (#{action.title}) for #{action.next_run_at.in_time_zone(action.timezone).strftime("%Y-%m-%d %H:%M %Z")}."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    "Error: #{e.message}"
  end

  private
    def resolve_chat(chat_id)
      return current_chat if chat_id.blank?

      agent.account.chats.find_by(id: chat_id)
    end
end
