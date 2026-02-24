require "test_helper"

class Agents::SkillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @agent = agents(:one)
    post session_url, params: { email_address: @user.email_address, password: "password" }
  end

  test "index shows enabled and available skills" do
    get agent_skills_url(@agent)
    assert_response :success
  end

  test "create enables a skill for the agent" do
    skill = skills(:api_design)
    assert_difference -> { @agent.agent_skills.count }, 1 do
      post agent_skills_url(@agent), params: { skill_id: skill.id }
    end
    assert_redirected_to agent_skills_url(@agent)
  end

  test "destroy disables a skill for the agent" do
    agent_skill = agent_skills(:atlas_code_review)
    assert_difference -> { @agent.agent_skills.count }, -1 do
      delete agent_skill_url(@agent, agent_skill)
    end
    assert_redirected_to agent_skills_url(@agent)
  end

  test "cannot access other account agents" do
    other_agent = agents(:two)
    get agent_skills_url(other_agent)
    assert_response :not_found
  end

  test "member without access cannot reach agent skills" do
    delete session_url
    member = users(:teammate)
    post session_url, params: { email_address: member.email_address, password: "password" }

    get agent_skills_url(@agent)
    assert_response :not_found
  end
end
