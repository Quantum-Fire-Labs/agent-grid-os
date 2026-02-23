require "test_helper"

class CustomApps::TransfersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @member = users(:teammate)
    @custom_app = custom_apps(:slideshow)
    @original_agent = agents(:one)
    @target_agent = agents(:three)
  end

  test "admin can transfer app to another agent" do
    sign_in_as(@admin)

    post custom_app_transfer_path(@custom_app), params: { agent_id: @target_agent.id }

    assert_redirected_to custom_app_settings_path(@custom_app)
    assert_equal @target_agent, @custom_app.reload.agent
  end

  test "transfer removes existing agent access grant for the new owner" do
    sign_in_as(@admin)
    assert @custom_app.custom_app_agent_accesses.exists?(agent: @target_agent)

    post custom_app_transfer_path(@custom_app), params: { agent_id: @target_agent.id }

    assert_not @custom_app.reload.custom_app_agent_accesses.exists?(agent: @target_agent)
  end

  test "transfer to same agent is a no-op redirect" do
    sign_in_as(@admin)

    post custom_app_transfer_path(@custom_app), params: { agent_id: @original_agent.id }

    assert_redirected_to custom_app_settings_path(@custom_app)
    assert_equal @original_agent, @custom_app.reload.agent
  end

  test "member cannot transfer app" do
    sign_in_as(@member)

    post custom_app_transfer_path(@custom_app), params: { agent_id: @target_agent.id }

    assert_redirected_to root_path
    assert_equal @original_agent, @custom_app.reload.agent
  end

  test "cannot transfer to agent in another account" do
    sign_in_as(@admin)
    other_agent = agents(:two)

    post custom_app_transfer_path(@custom_app), params: { agent_id: other_agent.id }

    assert_response :not_found
    assert_equal @original_agent, @custom_app.reload.agent
  end
end
