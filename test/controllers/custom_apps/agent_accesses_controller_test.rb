require "test_helper"

class CustomApps::AgentAccessesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @member = users(:teammate)
    @custom_app = custom_apps(:slideshow)
  end

  test "admin can grant agent access" do
    sign_in_as(@admin)
    # Agent :one owns the app, :three already has access via fixture — use a new agent
    new_agent = Agent.create!(account: accounts(:one), name: "Spark")
    assert_difference "CustomAppAgentAccess.count", 1 do
      post custom_app_agent_accesses_path(@custom_app), params: { agent_id: new_agent.id }
    end
    assert_redirected_to custom_app_settings_path(@custom_app)
  end

  test "admin can revoke agent access" do
    sign_in_as(@admin)
    access = custom_app_agent_accesses(:nova_slideshow)
    assert_difference "CustomAppAgentAccess.count", -1 do
      delete custom_app_agent_access_path(@custom_app, access)
    end
    assert_redirected_to custom_app_settings_path(@custom_app)
  end

  test "rejects duplicate agent access" do
    sign_in_as(@admin)
    assert_no_difference "CustomAppAgentAccess.count" do
      post custom_app_agent_accesses_path(@custom_app), params: { agent_id: agents(:three).id }
    end
    assert_response :unprocessable_entity
  end

  test "member cannot grant agent access" do
    sign_in_as(@member)
    new_agent = Agent.create!(account: accounts(:one), name: "Spark")
    assert_no_difference "CustomAppAgentAccess.count" do
      post custom_app_agent_accesses_path(@custom_app), params: { agent_id: new_agent.id }
    end
    assert_redirected_to root_path
  end

  test "member cannot revoke agent access" do
    sign_in_as(@member)
    access = custom_app_agent_accesses(:nova_slideshow)
    assert_no_difference "CustomAppAgentAccess.count" do
      delete custom_app_agent_access_path(@custom_app, access)
    end
    assert_redirected_to root_path
  end
end
