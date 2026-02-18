class Agent::Tools::WriteFile < Agent::Tools::Base
  def self.definition
    {
      type: "function",
      function: {
        name: "write_file",
        description: "Write content to a file in your workspace. Creates parent directories automatically.",
        parameters: {
          type: "object",
          properties: {
            path: { type: "string", description: "Relative file path within the workspace (e.g. 'src/main.py')" },
            content: { type: "string", description: "The content to write to the file" }
          },
          required: [ "path", "content" ]
        }
      }
    }
  end

  def call
    path = arguments["path"]
    content = arguments["content"]
    return "Error: path is required" if path.blank?
    return "Error: content is required" if content.nil?

    return "Error: path must be relative (no leading /)" if path.start_with?("/")
    return "Error: path cannot contain .." if path.include?("..")

    workspace = Agent::Workspace.new(agent)
    full_path = workspace.path.join(path)

    # Verify the resolved path is inside the workspace
    return "Error: path escapes workspace" unless full_path.to_s.start_with?(workspace.path.to_s)

    Rails.logger.info("[Agent::Tools::WriteFile] agent=#{agent.name} path=#{path} size=#{content.length}")

    FileUtils.mkdir_p(full_path.dirname)
    File.write(full_path, content)

    "Wrote #{content.length} bytes to #{path}"
  end
end
