class Agent::Tools::ReadFile < Agent::Tools::Base
  MAX_CHARS = 12_000

  def self.definition
    {
      type: "function",
      function: {
        name: "read_file",
        description: "Read the contents of a file in your workspace.",
        parameters: {
          type: "object",
          properties: {
            path: { type: "string", description: "Relative file path within the workspace (e.g. 'src/main.py')" }
          },
          required: [ "path" ]
        }
      }
    }
  end

  def call
    path = arguments["path"]
    return "Error: path is required" if path.blank?

    return "Error: path must be relative (no leading /)" if path.start_with?("/")
    return "Error: path cannot contain .." if path.include?("..")

    workspace = Agent::Workspace.new(agent)
    full_path = workspace.path.join(path)

    return "Error: path escapes workspace" unless full_path.to_s.start_with?(workspace.path.to_s)
    return "Error: file not found: #{path}" unless File.exist?(full_path)
    return "Error: not a file: #{path}" unless File.file?(full_path)

    Rails.logger.info("[Agent::Tools::ReadFile] agent=#{agent.name} path=#{path}")

    content = File.read(full_path)
    content = content.truncate(MAX_CHARS, omission: "\n\n[Truncated]") if content.length > MAX_CHARS
    content
  end
end
