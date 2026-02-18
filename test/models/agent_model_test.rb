require "test_helper"

class AgentModelTest < ActiveSupport::TestCase
  test "uniqueness of agent and provider" do
    existing = agent_models(:atlas_openrouter)
    duplicate = AgentModel.new(agent: existing.agent, provider: existing.provider, model: "test", designation: "fallback")
    assert_not duplicate.valid?
    assert duplicate.errors[:provider_id].any?
  end

  test "model is required" do
    am = AgentModel.new(agent: agents(:one), provider: providers(:openai), designation: "fallback")
    assert_not am.valid?
    assert am.errors[:model].any?
  end

  test "demotes existing default when new default is set" do
    agent = agents(:one)
    existing_default = agent_models(:atlas_openrouter)
    assert existing_default.designation_default?

    new_am = AgentModel.create!(agent: agent, provider: providers(:openai), model: "gpt-4o", designation: "default")
    assert new_am.designation_default?
    assert existing_default.reload.designation_fallback?
  end

  test "provider must belong to same account as agent" do
    agent = agents(:one)
    other_provider = providers(:two)

    am = AgentModel.new(agent: agent, provider: other_provider, model: "test", designation: "fallback")
    assert_not am.valid?
    assert am.errors[:provider].any?
  end

  test "designation only allows default and fallback" do
    assert_raises(ArgumentError) do
      AgentModel.new(designation: "none")
    end
  end
end
