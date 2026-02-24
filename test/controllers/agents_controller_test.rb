require "test_helper"

class AgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @agent = agents(:one)
  end

  # new

  test "new renders agent form" do
    get new_agent_path
    assert_response :success
  end

  test "new lists available personas" do
    get new_agent_path
    assert_select "a.persona-link", minimum: 1
  end

  test "new with valid persona pre-fills form from persona" do
    get new_agent_path, params: { persona: "the_orchestrator" }

    assert_response :success
    assert_select "h1", text: /The Orchestrator/
    assert_select "input[name='from_persona'][value='the_orchestrator']"
  end

  test "new with unknown persona redirects to new agent path" do
    get new_agent_path, params: { persona: "nonexistent" }
    assert_redirected_to new_agent_path
  end

  test "new is accessible to members" do
    sign_in_as users(:teammate)
    get new_agent_path
    assert_response :success
  end

  # create

  test "create with valid params creates agent and redirects" do
    assert_difference "Agent.count", 1 do
      post agents_path, params: { agent: { name: "scout", title: "Scout", description: "A scout agent" } }
    end
    assert_redirected_to agent_path(Agent.last)
  end

  test "create applies personality preset by default" do
    post agents_path, params: {
      agent: { name: "scout", title: "Scout", description: "Desc", personality: "witty" }
    }

    agent = Agent.last
    assert agent.personality.include?("Dry, witty"), "expected personality preset to be applied"
  end

  test "create skips personality preset when from_persona is present" do
    raw_personality = "Strategic and composed."

    post agents_path, params: {
      from_persona: "the_orchestrator",
      agent: { name: "ops", title: "Ops", description: "Desc", personality: raw_personality }
    }

    assert_redirected_to agent_path(Agent.last)
    assert_equal raw_personality, Agent.last.personality
  end

  test "create from persona applies recommended_settings" do
    post agents_path, params: {
      from_persona: "the_orchestrator",
      agent: { name: "ops", title: "Ops", description: "Desc", personality: "Composed." }
    }

    assert_redirected_to agent_path(Agent.last)
    assert Agent.last.orchestrator?, "expected orchestrator to be enabled"
  end

  test "create with invalid params re-renders new form" do
    post agents_path, params: { agent: { name: "" } }

    assert_response :unprocessable_entity
    assert_select ".persona-link", minimum: 1
  end

  test "create with invalid params and from_persona shows persona header" do
    post agents_path, params: {
      from_persona: "the_orchestrator",
      agent: { name: "" }
    }

    assert_response :unprocessable_entity
    assert_select "h1", text: /The Orchestrator/
    assert_select "input[name='from_persona'][value='the_orchestrator']"
  end

  test "create is accessible to members" do
    sign_in_as users(:teammate)
    assert_difference "Agent.count", 1 do
      post agents_path, params: { agent: { name: "scout", title: "Scout" } }
    end
    assert_redirected_to agent_path(Agent.last)
  end

  test "create as member auto-assigns the creator" do
    sign_in_as users(:teammate)
    post agents_path, params: { agent: { name: "scout", title: "Scout" } }

    agent = Agent.last
    assert_includes agent.users, users(:teammate)
  end

  test "create as admin does not auto-assign the creator" do
    post agents_path, params: { agent: { name: "scout", title: "Scout" } }

    agent = Agent.last
    assert_not_includes agent.users, users(:one)
  end

  test "create requires authentication" do
    sign_out
    post agents_path, params: { agent: { name: "scout" } }
    assert_redirected_to new_session_path
  end

  # edit/update/destroy — sole member as agent admin

  test "sole member can edit their agent" do
    member = users(:teammate)
    agent = Current.account.agents.create!(name: "Solo")
    agent.agent_users.create!(user: member)

    sign_in_as member
    get edit_agent_path(agent)
    assert_response :success
  end

  test "sole member can update their agent" do
    member = users(:teammate)
    agent = Current.account.agents.create!(name: "Solo")
    agent.agent_users.create!(user: member)

    sign_in_as member
    patch agent_path(agent), params: { agent: { name: "Renamed" } }
    assert_redirected_to agent_path(agent)
    assert_equal "Renamed", agent.reload.name
  end

  test "sole member can destroy their agent" do
    member = users(:teammate)
    agent = Current.account.agents.create!(name: "Solo")
    agent.agent_users.create!(user: member)

    sign_in_as member
    assert_difference "Agent.count", -1 do
      delete agent_path(agent)
    end
  end

  test "member with co-users cannot edit agent" do
    member = users(:teammate)
    other = users(:one)
    agent = Current.account.agents.create!(name: "Shared")
    agent.agent_users.create!(user: member)
    agent.agent_users.create!(user: other)

    sign_in_as member
    get edit_agent_path(agent)
    assert_response :redirect
  end

  test "member not assigned to agent cannot edit it" do
    sign_in_as users(:teammate)
    get edit_agent_path(@agent)
    assert_response :not_found
  end
end
