class Agent::Tools::UpdateScheduledAction < Agent::Tools::Base
  include Agent::Tools::SchedulingParams

  def self.definition
    {
      type: "function",
      function: {
        name: "update_scheduled_action",
        description: "Update a scheduled reminder or automation (future runs only).",
        parameters: {
          type: "object",
          properties: {
            id: { type: "integer", description: "Scheduled action ID" },
            title: { type: "string", description: "New title" },
            timezone: { type: "string", description: "IANA timezone" },
            schedule: { type: "object", description: "Replacement schedule object" },
            message: { type: "string", description: "For reminders only" },
            tool_name: { type: "string", description: "For automations only" },
            arguments: { type: "object", description: "For automations only" }
          },
          required: %w[id]
        }
      }
    }
  end

  def call
    action = find_action
    return "Error: scheduled action not found" unless action
    return "Error: cannot update canceled or completed scheduled actions" if action.canceled? || action.completed?

    apply_updates(action)
    action.save!
    action.dispatch_later if action.next_run_at.present? && action.active?

    "Updated scheduled action ##{action.id}. Next run: #{action.next_run_at ? action.next_run_at.in_time_zone(action.timezone).strftime("%Y-%m-%d %H:%M %Z") : "none"}."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    "Error: #{e.message}"
  end

  private
    def find_action
      return nil if arguments["id"].blank?

      agent.account.scheduled_actions.find_by(id: arguments["id"], agent_id: agent.id)
    end

    def apply_updates(action)
      action.title = arguments["title"] if arguments["title"].present?

      if arguments.key?("timezone")
        action.timezone = effective_timezone(arguments["timezone"])
      end

      if action.reminder?
        action.payload = action.payload.merge("message" => arguments["message"]) if arguments.key?("message")
      else
        if arguments.key?("tool_name")
          action.payload = action.payload.merge("tool_name" => arguments["tool_name"])
        end
        if arguments.key?("arguments")
          raise ArgumentError, "arguments must be an object" unless arguments["arguments"].is_a?(Hash)

          action.payload = action.payload.merge("arguments" => arguments["arguments"])
        end
      end

      if arguments.key?("schedule")
        action.apply_schedule(arguments["schedule"])
      elsif arguments.key?("timezone")
        action.recalculate_next_run_at
      end

      ensure_payload_matches_mode(action)
    end

    def ensure_payload_matches_mode(action)
      if action.reminder? && (arguments.key?("tool_name") || arguments.key?("arguments"))
        raise ArgumentError, "tool_name/arguments apply only to automations"
      end
      if action.automation? && arguments.key?("message")
        raise ArgumentError, "message applies only to reminders"
      end
    end
end
