require "open3"

class Agent::Workspace
  CONTAINER_PREFIX = "thegrid-workspace"
  IMAGE = "thegrid-workspace:latest"
  EXEC_TIMEOUT = 30

  attr_reader :agent

  def initialize(agent)
    @agent = agent
  end

  def start
    if exists?
      if network_changed?
        recreate
      elsif !running?
        run_docker("start", container_name)
        Rails.logger.info("[Agent::Workspace] Started existing container for agent=#{agent.name}")
      end
    else
      create
    end
  rescue DockerError => e
    Rails.logger.error("[Agent::Workspace] Start failed for agent=#{agent.name}: #{e.message}")
  end

  def recreate
    destroy
    create
    Rails.logger.info("[Agent::Workspace] Recreated container for agent=#{agent.name} (network changed)")
  end

  def stop
    return unless running?

    run_docker("stop", container_name)
    Rails.logger.info("[Agent::Workspace] Stopped container for agent=#{agent.name}")
  rescue DockerError => e
    Rails.logger.warn("[Agent::Workspace] Stop failed for agent=#{agent.name}: #{e.message}")
  end

  def destroy
    return unless exists?

    run_docker("rm", "-f", container_name)
    Rails.logger.info("[Agent::Workspace] Destroyed container for agent=#{agent.name}")
  rescue DockerError => e
    Rails.logger.warn("[Agent::Workspace] Destroy failed for agent=#{agent.name}: #{e.message}")
  end

  def running?
    stdout, _, status = Open3.capture3("docker", "inspect", "-f", "{{.State.Running}}", container_name)
    status.success? && stdout.strip == "true"
  end

  def exists?
    _, _, status = Open3.capture3("docker", "inspect", container_name)
    status.success?
  end

  def exec(command, stdin: nil, timeout: EXEC_TIMEOUT)
    unless running?
      return { stdout: "", stderr: "Error: workspace container is not running", exit_code: 1 }
    end

    cmd = [ "docker", "exec" ]
    cmd += [ "-i" ] if stdin
    cmd += [ container_name, "bash", "-c", command ]

    opts = {}
    opts[:stdin_data] = stdin if stdin

    stdout, stderr, status = Timeout.timeout(timeout) do
      Open3.capture3(*cmd, **opts)
    end

    { stdout: stdout, stderr: stderr, exit_code: status.exitstatus }
  rescue Timeout::Error
    { stdout: "", stderr: "Error: command timed out after #{timeout}s", exit_code: 124 }
  end

  def exec_later(command, conversation:, label:, timeout: 600)
    Agent::WorkspaceExecJob.perform_later(agent, conversation, command, label: label, timeout: timeout)
  end

  def deliver_exec_result(command, conversation:, label:, timeout: 600)
    result = exec(command, timeout: timeout)

    output = +""
    output << result[:stdout] if result[:stdout].present?
    output << result[:stderr] if result[:stderr].present?
    output = output.presence || "(no output)"
    output = output.truncate(12_000, omission: "\n\n[Truncated]")

    status = result[:exit_code] == 0 ? "completed" : "failed (exit code #{result[:exit_code]})"

    msg = conversation.messages.create!(
      role: "system",
      content: "[#{label} #{status}]\n\n#{output}"
    )

    Turbo::StreamsChannel.broadcast_append_to(
      conversation,
      target: "chat-messages",
      partial: "agents/conversations/messages/message",
      locals: { message: msg, agent: agent }
    )

    conversation.enqueue_agent_reply
  end

  def path
    Rails.root.join("storage", "agents", agent.id.to_s, "workspace")
  end

  def home_path
    Rails.root.join("storage", "agents", agent.id.to_s, "home")
  end

  def container_name
    "#{CONTAINER_PREFIX}-#{agent.id}"
  end

  class DockerError < StandardError; end

  private

  def create
    FileUtils.mkdir_p(path)
    FileUtils.mkdir_p(home_path)
    run_docker(*build_run_command)
    # Fix ownership inside the container
    run_docker("exec", "-u", "root", container_name, "chown", "-R", "agent:agent", "/home/agent")
    run_docker("exec", "-u", "root", container_name, "chown", "agent:agent", "/workspace")
    Rails.logger.info("[Agent::Workspace] Created container for agent=#{agent.name}")
  end

  def desired_network
    agent.network_mode_full? ? "bridge" : "none"
  end

  def current_network
    stdout, _, status = Open3.capture3("docker", "inspect", "-f", "{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}", container_name)
    return nil unless status.success?

    # Inspect network mode name instead
    stdout, _, status = Open3.capture3("docker", "inspect", "-f", "{{.HostConfig.NetworkMode}}", container_name)
    status.success? ? stdout.strip : nil
  end

  def network_changed?
    current = current_network
    return false if current.nil?

    current != desired_network
  end

  def build_run_command
    cmd = [
      "run", "-d",
      "--name", container_name,
      "--network", desired_network,
      "--restart", "unless-stopped",
      "-v", "#{path}:/workspace",
      "-v", "#{home_path}:/home/agent",
      "-e", "PATH=/home/agent/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
      "-w", "/workspace"
    ]

    agent.plugins.each do |plugin|
      plugin.mounts.each do |mount|
        source = resolve_mount_source(mount["source"], plugin)
        cmd += [ "-v", "#{source}:#{mount["target"]}:ro" ]
      end
    end

    cmd += [ IMAGE, "sleep", "infinity" ]
    cmd
  end

  def resolve_mount_source(source, plugin)
    if Pathname.new(source).absolute?
      source
    else
      plugin.path.join(source).to_s
    end
  end

  def run_docker(*args)
    stdout, stderr, status = Open3.capture3("docker", *args)
    return stdout if status.success?

    raise DockerError, "docker #{args.first} exited #{status.exitstatus}: #{stderr.strip}"
  end
end
