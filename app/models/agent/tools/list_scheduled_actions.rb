class Agent::Tools::ListScheduledActions < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "list_scheduled_actions",
        description: "List scheduled reminders and automations.",
        parameters: {
          type: "object",
          properties: {
            status: { type: "string", description: "Optional status filter (active, paused, canceled, completed)" },
            limit: { type: "integer", description: "Maximum items to return (default 20, max 100)" }
          }
        }
      }
    }
  end

  def call
    limit = [ arguments["limit"].to_i, 100 ].select(&:positive?).first || 20
    scope = agent.account.scheduled_actions.where(agent: agent)
    scope = scope.where(status: arguments["status"]) if arguments["status"].present?
    actions = scope.order(next_run_at: :asc, created_at: :desc).limit(limit)

    return "No scheduled actions found." if actions.empty?

    actions.map { |action|
      time_text = action.next_run_at ? action.next_run_at.in_time_zone(action.timezone).strftime("%Y-%m-%d %H:%M %Z") : "none"
      "- ##{action.id} [#{action.summary_label}] #{action.title} (#{action.status}) next: #{time_text}"
    }.join("\n")
  end
end
