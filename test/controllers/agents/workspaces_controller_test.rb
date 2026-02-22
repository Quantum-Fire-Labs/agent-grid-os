require "test_helper"

class Agents::WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @agent = agents(:one)
  end

  test "show renders workspace page" do
    get agent_workspace_path(@agent)
    assert_response :success
  end

  test "update toggles workspace enabled" do
    stub_docker_calls do
      patch agent_workspace_path(@agent), params: { workspace: { enabled: "1" } }
      assert_redirected_to agent_workspace_path(@agent)
      assert @agent.reload.workspace_enabled?
    end
  end

  test "update disables workspace" do
    @agent.update!(workspace_enabled: true)
    stub_docker_calls do
      patch agent_workspace_path(@agent), params: { workspace: { enabled: "0" } }
      assert_redirected_to agent_workspace_path(@agent)
      refute @agent.reload.workspace_enabled?
    end
  end

  test "show requires authentication" do
    sign_out
    get agent_workspace_path(@agent)
    assert_redirected_to new_session_path
  end

  test "cannot access other account agent" do
    other_agent = agents(:two)
    get agent_workspace_path(other_agent)
    assert_response :not_found
  end

  private
  def stub_docker_calls(&block)
    original_method = Open3.method(:capture3)
    fake = ->(*args) { ["", "", Struct.new(:success?, :exitstatus).new(false, 1)] }
    
    Open3.define_singleton_method(:capture3, &fake)
    block.call
  ensure
    Open3.define_singleton_method(:capture3, original_method)
  end
end
