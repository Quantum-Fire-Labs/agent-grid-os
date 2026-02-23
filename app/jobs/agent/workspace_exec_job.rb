class Agent::WorkspaceExecJob < ApplicationJob
  queue_as :default

  def perform(agent, chat, command, label:, timeout: 600, stdin: nil)
    Agent::Workspace.new(agent).deliver_exec_result(
      command, chat: chat, label: label, timeout: timeout, stdin: stdin
    )
  end
end
