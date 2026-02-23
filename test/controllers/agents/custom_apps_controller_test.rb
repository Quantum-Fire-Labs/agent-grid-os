require "test_helper"

class Agents::CustomAppsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @agent = agents(:one)
  end

  test "admin can view agent apps" do
    sign_in_as(@admin)
    get agent_custom_apps_url(@agent)
    assert_response :success
  end

  test "shows only this agent's apps" do
    sign_in_as(@admin)
    get agent_custom_apps_url(@agent)
    assert_response :success
    assert_select ".skill-name", text: "Slideshow"
  end

  test "member cannot view agent apps" do
    sign_in_as(users(:teammate))
    get agent_custom_apps_url(@agent)
    assert_redirected_to root_path
  end

  test "scoped to current account" do
    sign_in_as(@admin)
    get agent_custom_apps_url(agents(:two))
    assert_response :not_found
  end
end
