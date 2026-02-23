require "test_helper"

class Agent::Tools::ListSkillsTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:one)
  end

  test "lists enabled skills" do
    result = Agent::Tools::ListSkills.new(
      agent: @agent,
      arguments: {}
    ).call

    assert_includes result, "Code Review"
  end

  test "includes description when present" do
    result = Agent::Tools::ListSkills.new(
      agent: @agent,
      arguments: {}
    ).call

    assert_includes result, "Code Review: Guidelines for reviewing code"
  end

  test "does not list skills from other agents" do
    result = Agent::Tools::ListSkills.new(
      agent: @agent,
      arguments: {}
    ).call

    assert_no_match(/Support Workflow/, result)
  end

  test "returns message when no skills enabled" do
    @agent.agent_skills.destroy_all
    result = Agent::Tools::ListSkills.new(
      agent: @agent,
      arguments: {}
    ).call

    assert_equal "No skills enabled.", result
  end
end
