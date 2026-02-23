require "test_helper"

class SkillTest < ActiveSupport::TestCase
  test "valid skill" do
    skill = Skill.new(account: accounts(:one), name: "New Skill", body: "Instructions here")
    assert skill.valid?
  end

  test "requires name" do
    skill = Skill.new(account: accounts(:one), body: "Instructions")
    assert_not skill.valid?
    assert skill.errors[:name].any?
  end

  test "requires body" do
    skill = Skill.new(account: accounts(:one), name: "Test")
    assert_not skill.valid?
    assert skill.errors[:body].any?
  end

  test "name is unique per account" do
    existing = skills(:code_review)
    skill = Skill.new(account: existing.account, name: existing.name, body: "Other")
    assert_not skill.valid?
  end

  test "same name allowed on different accounts" do
    skill = Skill.new(account: accounts(:two), name: skills(:code_review).name, body: "Other")
    assert skill.valid?
  end

  test "destroying skill cascades to agent_skills" do
    skill = skills(:code_review)
    assert_difference "AgentSkill.count", -1 do
      skill.destroy
    end
  end
end
