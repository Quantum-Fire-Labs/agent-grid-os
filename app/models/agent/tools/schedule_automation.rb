class Agent::Tools::ScheduleAutomation < Agent::Tools::Base
  include Agent::Tools::SchedulingParams

  def self.definition
    {
      type: "function",
      function: {
        name: "schedule_automation",
        description: "Schedule a tool or script to run later. This executes the saved tool payload directly at runtime.",
        parameters: {
          type: "object",
          properties: {
            title: { type: "string", description: "Short automation title" },
            tool_name: { type: "string", description: "Tool name to execute later (e.g. exec, custom_lint, plugin tool)" },
            arguments: { type: "object", description: "JSON arguments for the tool (snapshotted at schedule time)" },
            timezone: { type: "string", description: "IANA timezone (optional; defaults to the user's timezone when available)" },
            chat_id: { type: "integer", description: "Optional chat ID for posting status/results" },
            schedule: {
              type: "object",
              description: "When to run. Use {kind:'once', run_at:'RFC3339'} or {kind:'recurring', rule:{...}}."
            }
          },
          required: %w[title tool_name arguments schedule]
        }
      }
    }
  end

  def call
    return "Error: title is required" if arguments["title"].blank?
    return "Error: tool_name is required" if arguments["tool_name"].blank?
    return "Error: arguments must be an object" unless arguments["arguments"].is_a?(Hash)

    tz = effective_timezone(arguments["timezone"])
    chat = resolve_chat(arguments["chat_id"])

    payload = {
      "tool_name" => arguments["tool_name"],
      "arguments" => arguments["arguments"]
    }
    payload["chat_id"] = chat.id if chat

    action = agent.account.scheduled_actions.new(
      agent: agent,
      chat: chat,
      created_by_user: scheduling_user,
      created_from_message: context[:user_message_record],
      title: arguments["title"],
      run_mode: "direct_tool",
      payload: payload,
      timezone: tz
    )

    parse_schedule!(action, timezone: tz)
    action.save!
    action.dispatch_later

    "Scheduled automation ##{action.id} (#{action.title}) for #{action.next_run_at.in_time_zone(action.timezone).strftime("%Y-%m-%d %H:%M %Z")}."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    "Error: #{e.message}"
  end

  private
    def resolve_chat(chat_id)
      return nil if chat_id.blank?

      agent.account.chats.find_by(id: chat_id)
    end
end
