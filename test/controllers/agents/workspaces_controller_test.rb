require "test_helper"

class Agents::WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @agent = agents(:one)
  end

  test "show renders workspace page" do
    get agent_workspace_path(@agent)
    assert_response :success
  end

  test "update toggles workspace enabled" do
    patch agent_workspace_path(@agent), params: { workspace: { enabled: "1" } }
    assert_redirected_to agent_workspace_path(@agent)
    assert @agent.reload.workspace_enabled?
  end

  test "update disables workspace" do
    @agent.update!(workspace_enabled: true)
    patch agent_workspace_path(@agent), params: { workspace: { enabled: "0" } }
    assert_redirected_to agent_workspace_path(@agent)
    refute @agent.reload.workspace_enabled?
  end

  test "show requires authentication" do
    sign_out
    get agent_workspace_path(@agent)
    assert_redirected_to new_session_path
  end

  test "cannot access other account agent" do
    other_agent = agents(:two)
    get agent_workspace_path(other_agent)
    assert_response :not_found
  end
end
