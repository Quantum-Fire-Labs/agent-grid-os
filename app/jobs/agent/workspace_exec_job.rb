class Agent::WorkspaceExecJob < ApplicationJob
  queue_as :default

  def perform(agent, conversation, command, label:, timeout: 600)
    Agent::Workspace.new(agent).deliver_exec_result(
      command, conversation: conversation, label: label, timeout: timeout
    )
  end
end
