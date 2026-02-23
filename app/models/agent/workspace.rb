require "open3"

class Agent::Workspace
  CONTAINER_PREFIX = "agentgridos-workspace"
  IMAGE = "ghcr.io/quantum-fire-labs/agent-grid-os/workspace:latest"
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

  def exec_later(command, chat:, label:, timeout: 600)
    Agent::WorkspaceExecJob.perform_later(agent, chat, command, label: label, timeout: timeout)
  end

  def deliver_exec_result(command, chat:, label:, timeout: 600)
    result = exec(command, timeout: timeout)

    output = +""
    output << result[:stdout] if result[:stdout].present?
    output << result[:stderr] if result[:stderr].present?
    output = output.presence || "(no output)"
    output = output.truncate(12_000, omission: "\n\n[Truncated]")

    status = result[:exit_code] == 0 ? "completed" : "failed (exit code #{result[:exit_code]})"

    msg = chat.messages.create!(
      role: "system",
      content: "[#{label} #{status}]\n\n#{output}\n\nReview the output and let the user know what happened."
    )

    Turbo::StreamsChannel.broadcast_append_to(
      chat,
      target: "chat-messages",
      partial: "chats/messages/message",
      locals: { message: msg, agent: agent }
    )

    if chat.respond_to?(:enqueue_agent_reply)
      chat.enqueue_agent_reply(agent: agent)
    else
      chat.enqueue_agent_reply
    end
  end

  def path
    Rails.root.join("storage", "agents", agent.id.to_s, "workspace")
  end

  def sanitized_path(relative_path)
    cleaned = Pathname.new(relative_path).cleanpath.to_s
    raise ArgumentError, "Path escapes workspace" if cleaned.start_with?("/") || cleaned.start_with?("..")
    cleaned
  end

  def read_file(relative_path)
    return nil unless running?

    safe_path = sanitized_path(relative_path)
    result = exec("cat #{Shellwords.shellescape(safe_path)} 2>/dev/null")
    result[:exit_code] == 0 ? result[:stdout] : nil
  end

  def list(relative_path = ".")
    return [] unless running?

    safe_path = sanitized_path(relative_path)
    result = exec("ls -la --time-style=long-iso #{Shellwords.shellescape(safe_path)} 2>/dev/null")
    return [] unless result[:exit_code] == 0

    result[:stdout].lines.drop(1).filter_map do |line|
      parts = line.strip.split(/\s+/, 8)
      next if parts.length < 8
      next if parts[7] == "." || parts[7] == ".."

      type = parts[0].start_with?("d") ? "directory" : "file"
      {
        name: parts[7],
        type: type,
        size: parts[4].to_i,
        modified_at: "#{parts[5]} #{parts[6]}"
      }
    end
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
      cleanup_stale_app_directories
      run_docker("exec", "-u", "root", container_name, "chown", "-R", "agent:agent", "/home/agent")
      run_docker("exec", "-u", "root", container_name, "chown", "-R", "agent:agent", "/workspace")
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
        "-v", "#{host_path_for(path)}:/workspace",
        "-v", "#{host_path_for(home_path)}:/home/agent",
        "-e", "PATH=/home/agent/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "-w", "/workspace"
      ]

      resolved_keychains.each do |kc|
        cmd += [ "-e", "#{kc.name}=#{kc.api_key}" ]
      end

      agent.plugins.each do |plugin|
        plugin.mounts.each do |mount|
          source = resolve_mount_source(mount["source"], plugin)
          cmd += [ "-v", "#{host_path_for(source)}:#{mount["target"]}:ro" ]
        end
      end

      agent.accessible_apps.each do |app|
        FileUtils.mkdir_p(app.files_path)
        cmd += [ "-v", "#{host_path_for(app.files_path)}:/workspace/apps/#{app.slug}" ]
      end

      cmd += [ IMAGE, "sleep", "infinity" ]
      cmd
    end

    # Remove stale app directories left behind by previous Docker mount points.
    # When an app is transferred or access revoked, the old mount-point directory
    # persists on disk (owned by uid 1001). Runs inside the NEW container after
    # creation — stale dirs are regular directories here (not mounts), so rm works.
    def cleanup_stale_app_directories
      current_slugs = agent.accessible_apps.pluck(:slug).to_set
      apps_dir = path.join("apps")
      return unless apps_dir.exist?

      apps_dir.children.each do |child|
        next unless child.directory?
        next if current_slugs.include?(child.basename.to_s)

        run_docker("exec", "-u", "root", container_name, "rm", "-rf", "/workspace/apps/#{child.basename}")
      end
    end

    # Translate in-container storage paths to host-side paths for Docker volume mounts.
    # When the Rails app runs inside Docker, paths like /rails/storage/agents/1/workspace
    # don't exist on the host. HOST_STORAGE_PATH maps to the host directory that's
    # bind-mounted as /rails/storage inside the container.
    def host_path_for(container_path)
      host_base = ENV["HOST_STORAGE_PATH"].presence
      return container_path.to_s unless host_base

      container_base = Rails.root.join("storage").to_s
      container_path.to_s.sub(container_base, host_base)
    end

    def resolve_mount_source(source, plugin)
      if Pathname.new(source).absolute?
        source
      else
        plugin.path.join(source).to_s
      end
    end

    def resolved_keychains
      account_kcs = agent.account.key_chains.where(sandbox_accessible: true).index_by(&:name)
      agent_kcs = agent.key_chains.where(sandbox_accessible: true).index_by(&:name)
      account_kcs.merge(agent_kcs).values
    end

    def run_docker(*args)
      stdout, stderr, status = Open3.capture3("docker", *args)
      return stdout if status.success?

      raise DockerError, "docker #{args.first} exited #{status.exitstatus}: #{stderr.strip}"
    end
end
