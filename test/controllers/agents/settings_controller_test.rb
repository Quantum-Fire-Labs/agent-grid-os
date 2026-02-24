require "test_helper"

class Agents::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @agent = agents(:one)
  end

  test "show renders agent settings" do
    get agent_settings_path(@agent)
    assert_response :success
  end

  test "update saves tts provider" do
    patch agent_settings_path(@agent), params: { agent_settings: { tts_provider: "elevenlabs" } }

    assert_redirected_to agent_settings_path(@agent)
    assert_equal "elevenlabs", @agent.configs.find_by(key: "tts_provider").value
  end

  test "update saves voice" do
    patch agent_settings_path(@agent), params: { agent_settings: { voice: "nova" } }

    assert_redirected_to agent_settings_path(@agent)
    assert_equal "nova", @agent.configs.find_by(key: "voice").value
  end

  test "update saves tts enabled" do
    patch agent_settings_path(@agent), params: { agent_settings: { tts_enabled: "false" } }

    assert_redirected_to agent_settings_path(@agent)
    assert_equal "false", @agent.configs.find_by(key: "tts_enabled").value
  end

  test "update saves stt provider" do
    patch agent_settings_path(@agent), params: { agent_settings: { stt_provider: "local" } }

    assert_redirected_to agent_settings_path(@agent)
    assert_equal "local", @agent.configs.find_by(key: "stt_provider").value
  end

  test "update saves tts speed" do
    patch agent_settings_path(@agent), params: { agent_settings: { tts_speed: "0.85" } }

    assert_redirected_to agent_settings_path(@agent)
    assert_equal "0.85", @agent.configs.find_by(key: "tts_speed").value
  end

  test "update no longer handles workspace enabled" do
    patch agent_settings_path(@agent), params: { agent_settings: { workspace_enabled: "1" } }

    assert_redirected_to agent_settings_path(@agent)
    refute @agent.reload.workspace_enabled?, "workspace_enabled should not be toggled via settings"
  end

  test "update ignores blank voice" do
    patch agent_settings_path(@agent), params: { agent_settings: { voice: "" } }

    assert_redirected_to agent_settings_path(@agent)
    assert_nil @agent.configs.find_by(key: "voice")
  end

  test "update enables orchestrator" do
    refute @agent.orchestrator?

    patch agent_settings_path(@agent), params: { agent: { orchestrator: "true" } }

    assert_redirected_to agent_settings_path(@agent)
    assert @agent.reload.orchestrator?
  end

  test "update disables orchestrator" do
    @agent.update!(orchestrator: true)

    patch agent_settings_path(@agent), params: { agent: { orchestrator: "false" } }

    assert_redirected_to agent_settings_path(@agent)
    refute @agent.reload.orchestrator?
  end

  test "orchestrator update does not process agent_settings params" do
    patch agent_settings_path(@agent), params: { agent: { orchestrator: "true" }, agent_settings: { voice: "nova" } }

    assert_redirected_to agent_settings_path(@agent)
    assert_nil @agent.configs.find_by(key: "voice"), "voice config should not have been saved"
  end

  test "sole member can view settings" do
    member = users(:teammate)
    agent = Current.account.agents.create!(name: "Solo")
    agent.agent_users.create!(user: member)

    sign_in_as member
    get agent_settings_path(agent)
    assert_response :success
  end

  test "sole member can update settings" do
    member = users(:teammate)
    agent = Current.account.agents.create!(name: "Solo")
    agent.agent_users.create!(user: member)

    sign_in_as member
    patch agent_settings_path(agent), params: { agent_settings: { voice: "nova" } }
    assert_redirected_to agent_settings_path(agent)
    assert_equal "nova", agent.configs.find_by(key: "voice").value
  end

  test "member with co-users cannot view settings" do
    member = users(:teammate)
    agent = Current.account.agents.create!(name: "Shared")
    agent.agent_users.create!(user: member)
    agent.agent_users.create!(user: users(:one))

    sign_in_as member
    get agent_settings_path(agent)
    assert_response :redirect
  end

  test "member without access cannot reach settings" do
    sign_in_as users(:teammate)
    get agent_settings_path(@agent)
    assert_response :not_found
  end

  test "show requires authentication" do
    sign_out
    get agent_settings_path(@agent)
    assert_redirected_to new_session_path
  end

  test "cannot access other account agent" do
    other_agent = agents(:two)
    get agent_settings_path(other_agent)
    assert_response :not_found
  end
end
