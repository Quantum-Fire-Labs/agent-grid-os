require "test_helper"

class Agents::FactoryResetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @agent = agents(:one)
  end

  test "create wipes memories and chats" do
    assert @agent.memories.any?

    post agent_factory_reset_path(@agent)

    assert_redirected_to agent_path(@agent)
    assert_equal 0, @agent.memories.count
  end

  test "create destroys custom apps" do
    app = @agent.custom_apps.create!(
      account: @agent.account,
      slug: "test-app",
      entrypoint: "index.html"
    )

    post agent_factory_reset_path(@agent)

    assert_redirected_to agent_path(@agent)
    assert_not CustomApp.exists?(app.id)
  end

  test "create preserves agent config" do
    @agent.update!(personality: "Friendly", instructions: "Be helpful")

    post agent_factory_reset_path(@agent)

    @agent.reload
    assert_equal "Friendly", @agent.personality
    assert_equal "Be helpful", @agent.instructions
  end

  test "non-admin is redirected" do
    sign_out
    sign_in_as users(:teammate)

    post agent_factory_reset_path(@agent)
    assert_response :redirect
  end

  test "cannot access other account agent" do
    other_agent = agents(:two)
    post agent_factory_reset_path(other_agent)
    assert_response :not_found
  end
end
