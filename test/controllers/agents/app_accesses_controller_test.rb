require "test_helper"

class Agents::AppAccessesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @agent = agents(:three)
    post session_url, params: { email_address: @user.email_address, password: "password" }
  end

  test "index shows granted and available apps" do
    get agent_app_accesses_url(@agent)
    assert_response :success
  end

  test "create grants app access" do
    app = custom_apps(:draft_app)
    assert_difference -> { @agent.custom_app_agent_accesses.count }, 1 do
      post agent_app_accesses_url(@agent), params: { custom_app_id: app.id }
    end
    assert_redirected_to agent_app_accesses_url(@agent)
  end

  test "create rejects duplicate access" do
    app = custom_apps(:slideshow)
    assert_no_difference -> { CustomAppAgentAccess.count } do
      post agent_app_accesses_url(@agent), params: { custom_app_id: app.id }
    end
    assert_redirected_to agent_app_accesses_url(@agent)
  end

  test "destroy revokes app access" do
    access = custom_app_agent_accesses(:nova_slideshow)
    assert_difference -> { @agent.custom_app_agent_accesses.count }, -1 do
      delete agent_app_access_url(@agent, access)
    end
    assert_redirected_to agent_app_accesses_url(@agent)
  end

  test "cannot access other account agents" do
    other_agent = agents(:two)
    get agent_app_accesses_url(other_agent)
    assert_response :not_found
  end

  test "non-admin is redirected" do
    delete session_url
    member = users(:teammate)
    post session_url, params: { email_address: member.email_address, password: "password" }

    get agent_app_accesses_url(@agent)
    assert_response :redirect
  end
end
