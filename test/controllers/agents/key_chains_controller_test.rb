require "test_helper"

class Agents::KeyChainsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @agent = agents(:one)
    post session_url, params: { email_address: @user.email_address, password: "password" }
  end

  test "index shows agent and account keychains" do
    get agent_key_chains_url(@agent)
    assert_response :success
  end

  test "new renders form" do
    get new_agent_key_chain_url(@agent)
    assert_response :success
    assert_select "form"
  end

  test "create adds keychain to agent" do
    assert_difference -> { @agent.key_chains.count }, 1 do
      post agent_key_chains_url(@agent), params: { key_chain: { name: "AGENT_NEW", secret: "agentsecret", sandbox_accessible: true } }
    end
    assert_redirected_to agent_key_chains_url(@agent)

    kc = @agent.key_chains.find_by(name: "AGENT_NEW")
    assert_equal "agentsecret", kc.api_key
    assert kc.sandbox_accessible?
  end

  test "create with invalid params re-renders form" do
    post agent_key_chains_url(@agent), params: { key_chain: { name: "", secret: "x" } }
    assert_response :unprocessable_entity
  end

  test "edit renders form" do
    kc = key_chains(:agent_sandbox_key)
    get edit_agent_key_chain_url(@agent, kc)
    assert_response :success
    assert_select "form"
  end

  test "update changes keychain" do
    kc = key_chains(:agent_sandbox_key)
    patch agent_key_chain_url(@agent, kc), params: { key_chain: { name: "RENAMED", secret: "" } }
    assert_redirected_to agent_key_chains_url(@agent)

    assert_equal "RENAMED", kc.reload.name
  end

  test "destroy removes keychain" do
    kc = key_chains(:agent_sandbox_key)
    assert_difference -> { @agent.key_chains.count }, -1 do
      delete agent_key_chain_url(@agent, kc)
    end
    assert_redirected_to agent_key_chains_url(@agent)
  end

  test "cannot access other account agents" do
    other_agent = agents(:two)
    get agent_key_chains_url(other_agent)
    assert_response :not_found
  end

  test "non-admin is redirected" do
    delete session_url
    member = users(:teammate)
    post session_url, params: { email_address: member.email_address, password: "password" }

    get agent_key_chains_url(@agent)
    assert_response :redirect
  end
end
