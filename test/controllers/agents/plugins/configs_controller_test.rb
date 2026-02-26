require "test_helper"

class Agents::Plugins::ConfigsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    sign_in_as @admin
    @agent = agents(:one)
    @plugin = Current.account.plugins.create!(
      name: "missionbase_test_cfg",
      plugin_type: "tool",
      execution: "platform",
      config_schema: [
        { "key" => "MISSIONBASE_BASE_URL", "type" => "string", "scope" => "account", "label" => "Base URL" },
        { "key" => "MISSIONBASE_API_KEY", "type" => "secret", "scope" => "agent", "label" => "API Key" }
      ]
    )
    @agent.agent_plugins.create!(plugin: @plugin)
  end

  test "index renders agent-scoped config fields" do
    get agent_plugin_configs_path(@agent, @plugin)

    assert_response :success
    assert_includes response.body, "MISSIONBASE_API_KEY"
    assert_includes response.body, "type=\"password\""
    assert_not_includes response.body, "MISSIONBASE_BASE_URL"
  end

  test "create stores config on agent" do
    post agent_plugin_configs_path(@agent, @plugin), params: {
      plugin_config: { key: "MISSIONBASE_API_KEY", value: "secret-key" }
    }

    assert_redirected_to agent_plugin_configs_path(@agent, @plugin)
    config = @plugin.plugin_configs.find_by(configurable: @agent, key: "MISSIONBASE_API_KEY")
    assert_equal "secret-key", config.value
  end

  test "update changes existing agent config" do
    config = @plugin.plugin_configs.create!(configurable: @agent, key: "MISSIONBASE_API_KEY", value: "old")

    patch agent_plugin_config_path(@agent, @plugin, config), params: {
      plugin_config: { key: "MISSIONBASE_API_KEY", value: "new" }
    }

    assert_redirected_to agent_plugin_configs_path(@agent, @plugin)
    assert_equal "new", config.reload.value
  end

  test "destroy removes agent config" do
    config = @plugin.plugin_configs.create!(configurable: @agent, key: "MISSIONBASE_API_KEY", value: "old")

    delete agent_plugin_config_path(@agent, @plugin, config)

    assert_redirected_to agent_plugin_configs_path(@agent, @plugin)
    assert_not PluginConfig.exists?(config.id)
  end

  test "member without agent admin cannot access config page" do
    member = users(:teammate)
    shared_agent = Current.account.agents.create!(name: "Shared Agent")
    shared_agent.agent_users.create!(user: member)
    shared_agent.agent_users.create!(user: @admin)
    shared_agent.agent_plugins.create!(plugin: @plugin)

    sign_in_as member
    get agent_plugin_configs_path(shared_agent, @plugin)

    assert_response :redirect
  end

  test "plugin must be enabled on the agent" do
    other_plugin = Current.account.plugins.create!(
      name: "disabled_cfg_plugin",
      plugin_type: "tool",
      execution: "platform",
      config_schema: [ { "key" => "K", "type" => "string" } ]
    )

    get agent_plugin_configs_path(@agent, other_plugin)

    assert_response :not_found
  end
end
