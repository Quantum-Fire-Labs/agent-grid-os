require "test_helper"

class Agent::Tools::RemoveSkillTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:one)
  end

  test "removes an existing skill" do
    skill = skills(:code_review)
    result = Agent::Tools::RemoveSkill.new(
      agent: @agent,
      arguments: { "name" => skill.name }
    ).call

    assert_match /Removed/, result
    assert_nil @agent.account.skills.find_by(name: skill.name)
  end

  test "returns error for unknown skill" do
    result = Agent::Tools::RemoveSkill.new(
      agent: @agent,
      arguments: { "name" => "nonexistent" }
    ).call

    assert_match /Error/, result
  end

  test "requires name" do
    result = Agent::Tools::RemoveSkill.new(
      agent: @agent,
      arguments: {}
    ).call

    assert_match /Error/, result
  end
end
