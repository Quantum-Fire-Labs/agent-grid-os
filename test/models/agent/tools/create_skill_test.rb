require "test_helper"

class Agent::Tools::CreateSkillTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:one)
  end

  test "creates a new skill and enables it for the agent" do
    result = Agent::Tools::CreateSkill.new(
      agent: @agent,
      arguments: { "name" => "New Skill", "body" => "Do this thing", "description" => "A desc" }
    ).call

    assert_match /Created skill/, result

    skill = @agent.account.skills.find_by(name: "New Skill")
    assert skill
    assert_equal "Do this thing", skill.body
    assert_equal "A desc", skill.description
    assert_includes @agent.skills, skill
  end

  test "updates existing skill" do
    skill = skills(:code_review)
    @agent.agent_skills.find_or_create_by!(skill: skill)

    result = Agent::Tools::CreateSkill.new(
      agent: @agent,
      arguments: { "name" => skill.name, "body" => "Updated body" }
    ).call

    assert_match /Updated skill/, result
    assert_equal "Updated body", skill.reload.body
  end

  test "requires name" do
    result = Agent::Tools::CreateSkill.new(
      agent: @agent,
      arguments: { "body" => "Instructions" }
    ).call

    assert_match /Error/, result
  end

  test "auto-enables skill is idempotent" do
    skill = skills(:code_review)
    @agent.agent_skills.find_or_create_by!(skill: skill)

    assert_no_difference "AgentSkill.count" do
      Agent::Tools::CreateSkill.new(
        agent: @agent,
        arguments: { "name" => skill.name, "body" => "Updated" }
      ).call
    end
  end

  test "requires body" do
    result = Agent::Tools::CreateSkill.new(
      agent: @agent,
      arguments: { "name" => "No Body" }
    ).call

    assert_match /Error/, result
  end
end
