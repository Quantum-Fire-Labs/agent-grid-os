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
    assert_select "h1", text: /Agent Operations Manager/
    assert_select "input[name='from_persona'][value='the_orchestrator']"
  end

  test "new with unknown persona redirects to new agent path" do
    get new_agent_path, params: { persona: "nonexistent" }
    assert_redirected_to new_agent_path
  end

  test "new requires admin" do
    sign_in_as users(:teammate)
    get new_agent_path
    assert_redirected_to root_path
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
    assert_select "h1", text: /Agent Operations Manager/
    assert_select "input[name='from_persona'][value='the_orchestrator']"
  end

  test "create requires admin" do
    sign_in_as users(:teammate)
    post agents_path, params: { agent: { name: "scout" } }
    assert_redirected_to root_path
  end

  test "create requires authentication" do
    sign_out
    post agents_path, params: { agent: { name: "scout" } }
    assert_redirected_to new_session_path
  end
end
