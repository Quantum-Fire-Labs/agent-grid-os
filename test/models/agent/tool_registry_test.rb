require "test_helper"

class Agent::ToolRegistryTest < ActiveSupport::TestCase
  setup do
    @apps_with_manifests = []
  end

  teardown do
    @apps_with_manifests.each do |app|
      FileUtils.rm_f(app.agent_tools_manifest_path)
      app.remove_instance_variable(:@agent_tools_manifest) if app.instance_variable_defined?(:@agent_tools_manifest)
    end
  end

  test "definitions include app-specific tools when agent has own apps" do
    agent = agents(:one) # owns slideshow and draft_app
    write_manifest(custom_apps(:draft_app), "check_status")
    names = tool_names(agent)

    assert_includes names, "app_draft_app_check_status"
  end

  test "definitions include app-specific tools when agent has granted apps" do
    agent = agents(:three) # granted access to slideshow
    write_manifest(custom_apps(:slideshow), "list_slides")
    names = tool_names(agent)

    assert_includes names, "app_slideshow_list_slides"
  end

  test "definitions exclude generic app_data tools" do
    agent = agents(:one)
    names = tool_names(agent)

    assert_not_includes names, "list_app_tables"
    assert_not_includes names, "query_app_data"
    assert_not_includes names, "insert_app_data"
    assert_not_includes names, "update_app_data"
    assert_not_includes names, "delete_app_data"
  end

  test "definitions exclude app-specific tools when no accessible app has a manifest" do
    agent = Agent.create!(name: "Empty", account: accounts(:one))
    names = tool_names(agent)

    assert_not_includes names, "app_slideshow_list_slides"
  end

  test "definitions exclude workspace tools for non-workspace agent" do
    agent = agents(:three)
    names = tool_names(agent)

    assert_not_includes names, "exec"
    assert_not_includes names, "register_app"
  end

  test "definitions include orchestrator tools when agent is orchestrator" do
    agent = agents(:one)
    agent.update!(orchestrator: true)
    names = tool_names(agent)

    assert_includes names, "list_agents"
    assert_includes names, "get_agent"
    assert_includes names, "create_agent"
    assert_includes names, "update_agent"
  end

  test "definitions exclude orchestrator tools when agent is not orchestrator" do
    agent = agents(:one)
    refute agent.orchestrator?
    names = tool_names(agent)

    assert_not_includes names, "list_agents"
    assert_not_includes names, "get_agent"
    assert_not_includes names, "create_agent"
    assert_not_includes names, "update_agent"
  end

  test "definitions always include skill tools" do
    agent = agents(:one)
    names = tool_names(agent)

    assert_includes names, "create_skill"
    assert_includes names, "remove_skill"
    assert_includes names, "list_skills"
  end

  private
    def write_manifest(app, action_name)
      FileUtils.mkdir_p(app.files_path)
      File.write(app.agent_tools_manifest_path, {
        "version" => 1,
        "tools" => [
          {
            "name" => action_name,
            "description" => "Test tool",
            "parameters" => { "type" => "object", "properties" => {}, "required" => [] },
            "behavior" => { "kind" => "inspect" }
          }
        ]
      }.to_yaml)
      @apps_with_manifests << app
    end

    def tool_names(agent)
      Agent::ToolRegistry.definitions(agent: agent).map { |d| d[:function][:name] }
    end
end
