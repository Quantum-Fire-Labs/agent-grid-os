require "test_helper"

class AgentSkillTest < ActiveSupport::TestCase
  test "valid agent skill" do
    agent_skill = AgentSkill.new(agent: agents(:one), skill: skills(:api_design))
    assert agent_skill.valid?
  end

  test "prevents duplicate agent-skill pair" do
    existing = agent_skills(:atlas_code_review)
    duplicate = AgentSkill.new(agent: existing.agent, skill: existing.skill)
    assert_not duplicate.valid?
  end
end
