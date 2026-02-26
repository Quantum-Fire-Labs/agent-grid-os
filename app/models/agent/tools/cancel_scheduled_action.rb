class Agent::Tools::CancelScheduledAction < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "cancel_scheduled_action",
        description: "Cancel a scheduled reminder or automation by ID.",
        parameters: {
          type: "object",
          properties: {
            id: { type: "integer", description: "Scheduled action ID" }
          },
          required: %w[id]
        }
      }
    }
  end

  def call
    return "Error: id is required" if arguments["id"].blank?

    action = agent.account.scheduled_actions.find_by(id: arguments["id"], agent_id: agent.id)
    return "Error: scheduled action not found" unless action

    already_canceled = action.canceled?
    action.cancel
    already_canceled ? "Scheduled action ##{action.id} was already canceled." : "Canceled scheduled action ##{action.id}."
  end
end
