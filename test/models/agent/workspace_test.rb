require "test_helper"

class Agent::WorkspaceTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:one)
    @workspace = Agent::Workspace.new(@agent)
    @original_host_storage_path = ENV["HOST_STORAGE_PATH"]
  end

  teardown do
    if @original_host_storage_path
      ENV["HOST_STORAGE_PATH"] = @original_host_storage_path
    else
      ENV.delete("HOST_STORAGE_PATH")
    end
  end

  # ── path helpers ──

  test "path returns storage workspace path for agent" do
    assert_equal Rails.root.join("storage", "agents", @agent.id.to_s, "workspace"), @workspace.path
  end

  test "home_path returns storage home path for agent" do
    assert_equal Rails.root.join("storage", "agents", @agent.id.to_s, "home"), @workspace.home_path
  end

  test "container_name includes agent id" do
    assert_equal "agentgridos-workspace-#{@agent.id}", @workspace.container_name
  end

  # ── stream_exec ──

  test "stream_exec raises DockerError when container is not running" do
    # Agent fixture has no running container, so running? returns false
    assert_raises(Agent::Workspace::DockerError) do
      @workspace.stream_exec("echo hello") { |_line| }
    end
  end

  # ── build_run_command volume mounts ──

  test "build_run_command uses host paths for volume mounts when HOST_STORAGE_PATH is set" do
    ENV["HOST_STORAGE_PATH"] = "/opt/agent-grid-os/storage"
    cmd = @workspace.send(:build_run_command)

    workspace_volume = find_volume(cmd, ":/workspace")
    assert workspace_volume.start_with?("/opt/agent-grid-os/storage/agents/"),
      "Expected workspace host path, got: #{workspace_volume}"

    home_volume = find_volume(cmd, ":/home/agent")
    assert home_volume.start_with?("/opt/agent-grid-os/storage/agents/"),
      "Expected home host path, got: #{home_volume}"
  end

  test "build_run_command uses container paths when HOST_STORAGE_PATH is not set" do
    ENV.delete("HOST_STORAGE_PATH")
    cmd = @workspace.send(:build_run_command)

    workspace_volume = find_volume(cmd, ":/workspace")
    assert workspace_volume.start_with?(Rails.root.join("storage").to_s),
      "Expected container path, got: #{workspace_volume}"
  end

  test "build_run_command uses container paths when HOST_STORAGE_PATH is empty" do
    ENV["HOST_STORAGE_PATH"] = ""
    cmd = @workspace.send(:build_run_command)

    workspace_volume = find_volume(cmd, ":/workspace")
    assert workspace_volume.start_with?(Rails.root.join("storage").to_s),
      "Expected container path when HOST_STORAGE_PATH is empty, got: #{workspace_volume}"
  end

  private
    def find_volume(cmd, target_suffix)
      pair = cmd.each_cons(2).find { |flag, val| flag == "-v" && val.include?(target_suffix) }
      assert pair, "Expected a -v flag for #{target_suffix}"
      pair[1].split(":").first
    end
end
