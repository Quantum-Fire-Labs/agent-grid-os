class Agent::Tools::Exec < Agent::Tools::Base
  MAX_CHARS = 12_000
  MAX_TIMEOUT = 600

  def self.definition
    {
      type: "function",
      function: {
        name: "exec",
        description: "Execute a shell command in your workspace container. Use this to run code, install packages, or perform any terminal operation.",
        parameters: {
          type: "object",
          properties: {
            command: { type: "string", description: "The shell command to execute" },
            async: { type: "boolean", description: "Run the command in the background. Returns immediately and delivers the result when done." },
            timeout: { type: "integer", description: "Maximum execution time in seconds (default 30, max 600). Only relevant for long-running commands." }
          },
          required: [ "command" ]
        }
      }
    }
  end

  def call
    command = arguments["command"]
    return "Error: command is required" if command.blank?

    timeout = [ arguments["timeout"]&.to_i || Agent::Workspace::EXEC_TIMEOUT, MAX_TIMEOUT ].min

    Rails.logger.info("[Agent::Tools::Exec] agent=#{agent.name} command=#{command.truncate(200)} async=#{arguments["async"]}")

    workspace = Agent::Workspace.new(agent)

    if arguments["async"]
      chat = context[:chat]
      return "Error: async exec requires a chat context" unless chat

      workspace.exec_later(command, chat: chat, label: "exec", timeout: timeout)
      return "Command started in the background. You'll receive the result when it completes."
    end

    result = workspace.exec(command, timeout: timeout)

    output = +""
    output << result[:stdout] if result[:stdout].present?
    output << result[:stderr] if result[:stderr].present?
    output = output.presence || "(no output)"

    output = output.truncate(MAX_CHARS, omission: "\n\n[Truncated]") if output.length > MAX_CHARS

    if result[:exit_code] != 0
      "Exit code #{result[:exit_code]}:\n#{output}"
    else
      output
    end
  end
end
