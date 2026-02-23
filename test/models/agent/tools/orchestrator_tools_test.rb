require "test_helper"

class Agent::Tools::OrchestratorToolsTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:one)
    @agent.update!(orchestrator: true)
  end

  # --- list_agents ---

  test "list_agents returns all agents in account" do
    result = call_tool(Agent::Tools::ListAgents)

    assert_match /Agents \(\d+\)/, result
    assert_match /Atlas/, result
    assert_match /Nova/, result
  end

  test "list_agents does not include agents from other accounts" do
    result = call_tool(Agent::Tools::ListAgents)

    assert_no_match(/Beacon/, result)
  end

  test "list_agents shows orchestrator flag" do
    result = call_tool(Agent::Tools::ListAgents)

    assert_match /Atlas.*\[orchestrator\]/, result
  end

  # --- get_agent ---

  test "get_agent returns agent details" do
    result = call_tool(Agent::Tools::GetAgent, "name" => "Nova")

    assert_match /name: Nova/, result
    assert_match /title: Data Analyst/, result
    assert_match /status: asleep/, result
  end

  test "get_agent with unknown name" do
    result = call_tool(Agent::Tools::GetAgent, "name" => "Nonexistent")

    assert_match /Error.*no agent named 'Nonexistent'/, result
  end

  test "get_agent requires name" do
    result = call_tool(Agent::Tools::GetAgent, {})

    assert_match /Error.*name is required/, result
  end

  test "get_agent cannot see agents from other accounts" do
    result = call_tool(Agent::Tools::GetAgent, "name" => "Beacon")

    assert_match /Error.*no agent named 'Beacon'/, result
  end

  # --- create_agent ---

  test "create_agent creates a new agent" do
    result = call_tool(Agent::Tools::CreateAgent,
      "name" => "Spark", "title" => "Writer", "description" => "Writes content")

    assert_match /Created agent 'Spark'/, result

    created = @agent.account.agents.find_by(name: "Spark")
    assert created
    assert_equal "Writer", created.title
    assert_equal "Writes content", created.description
  end

  test "create_agent requires name" do
    result = call_tool(Agent::Tools::CreateAgent, {})

    assert_match /Error.*name is required/, result
  end

  test "create_agent rejects duplicate name" do
    result = call_tool(Agent::Tools::CreateAgent, "name" => "Atlas")

    assert_match /Error/, result
  end

  test "create_agent scopes to account" do
    call_tool(Agent::Tools::CreateAgent, "name" => "Beacon")

    # Beacon exists in account two, but creating in account one should work
    assert @agent.account.agents.find_by(name: "Beacon")
  end

  test "create_agent with network_mode" do
    call_tool(Agent::Tools::CreateAgent,
      "name" => "NetAgent", "network_mode" => "allowed")

    created = @agent.account.agents.find_by(name: "NetAgent")
    assert created.network_mode_allowed?
  end

  # --- update_agent ---

  test "update_agent updates fields" do
    result = call_tool(Agent::Tools::UpdateAgent,
      "name" => "Nova", "title" => "Senior Analyst", "description" => "Updated desc")

    assert_match /Updated agent 'Nova'/, result

    nova = @agent.account.agents.find_by(name: "Nova")
    assert_equal "Senior Analyst", nova.title
    assert_equal "Updated desc", nova.description
  end

  test "update_agent with unknown name" do
    result = call_tool(Agent::Tools::UpdateAgent,
      "name" => "Nonexistent", "title" => "X")

    assert_match /Error.*no agent named 'Nonexistent'/, result
  end

  test "update_agent requires name" do
    result = call_tool(Agent::Tools::UpdateAgent, "title" => "X")

    assert_match /Error.*name is required/, result
  end

  test "update_agent with no updatable fields" do
    result = call_tool(Agent::Tools::UpdateAgent, "name" => "Nova")

    assert_match /Error.*no fields to update/, result
  end

  test "update_agent cannot update agents from other accounts" do
    result = call_tool(Agent::Tools::UpdateAgent,
      "name" => "Beacon", "title" => "Hacked")

    assert_match /Error.*no agent named 'Beacon'/, result
  end

  # --- tool definitions ---

  test "all orchestrator tools have valid definitions" do
    [
      Agent::Tools::ListAgents,
      Agent::Tools::GetAgent,
      Agent::Tools::CreateAgent,
      Agent::Tools::UpdateAgent
    ].each do |tool_class|
      defn = tool_class.definition
      assert_equal "function", defn[:type]
      assert defn[:function][:name].present?
      assert defn[:function][:description].present?
      assert defn[:function][:parameters].present?
    end
  end

  private
    def call_tool(klass, arguments = {})
      klass.new(agent: @agent, arguments: arguments).call
    end
end
