require "test_helper"

class Agents::ClonesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @agent = agents(:one)
  end

  test "new renders clone form" do
    get new_agent_clone_path(@agent)
    assert_response :success
    assert_select "input[name=name]"
  end

  test "create clones agent with new name" do
    @agent.update!(personality: "Witty", instructions: "Be helpful")

    assert_difference -> { Agent.count }, 1 do
      post agent_clone_path(@agent), params: { name: "Atlas Clone" }
    end

    clone = Agent.find_by!(name: "Atlas Clone")
    assert_redirected_to agent_path(clone)
    assert_equal "Witty", clone.personality
    assert_equal "Be helpful", clone.instructions
    assert_equal @agent.network_mode, clone.network_mode
  end

  test "create clones agent models" do
    post agent_clone_path(@agent), params: { name: "Atlas Clone" }

    clone = Agent.find_by!(name: "Atlas Clone")
    assert_equal @agent.agent_models.count, clone.agent_models.count
  end

  test "create clones key chains" do
    assert @agent.key_chains.any?

    post agent_clone_path(@agent), params: { name: "Atlas Clone" }

    clone = Agent.find_by!(name: "Atlas Clone")
    assert_equal @agent.key_chains.count, clone.key_chains.count
  end

  test "create does not include memories by default" do
    assert @agent.memories.any?

    post agent_clone_path(@agent), params: { name: "Atlas Clone" }

    clone = Agent.find_by!(name: "Atlas Clone")
    assert_equal 0, clone.memories.count
  end

  test "create includes memories when requested" do
    assert @agent.memories.any?

    post agent_clone_path(@agent), params: { name: "Atlas Clone", include_memories: "1" }

    clone = Agent.find_by!(name: "Atlas Clone")
    assert_equal @agent.memories.count, clone.memories.count
  end

  test "member without access cannot reach agent" do
    sign_out
    sign_in_as users(:teammate)

    get new_agent_clone_path(@agent)
    assert_response :not_found
  end

  test "cannot access other account agent" do
    other_agent = agents(:two)
    get new_agent_clone_path(other_agent)
    assert_response :not_found
  end
end
