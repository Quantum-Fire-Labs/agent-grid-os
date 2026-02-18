require "test_helper"

class ProviderTest < ActiveSupport::TestCase
  test "key_chain resolves from account owner" do
    provider = providers(:one)
    assert_equal key_chains(:openrouter), provider.key_chain
  end

  test "key_chain resolves agent override over account fallback" do
    agent = agents(:one)
    provider = providers(:one)
    agent_kc = KeyChain.create!(owner: agent, name: "openrouter", secrets: { "api_key" => "sk-agent" })

    assert_equal agent_kc, provider.key_chain(agent: agent)
  end

  test "key_chain falls back to account when agent has none" do
    agent = agents(:one)
    provider = providers(:one)

    assert_equal key_chains(:openrouter), provider.key_chain(agent: agent)
  end

  test "key_chain returns nil when missing" do
    provider = providers(:one)
    provider.key_chain.destroy!
    assert_nil provider.reload.key_chain
  end

  test "key_chain uses current_agent accessor" do
    agent = agents(:one)
    provider = providers(:one)
    agent_kc = KeyChain.create!(owner: agent, name: "openrouter", secrets: { "api_key" => "sk-agent" })

    provider.current_agent = agent
    assert_equal agent_kc, provider.key_chain
  end

  test "connected? delegates to client for key-based provider" do
    provider = providers(:one)
    assert provider.connected?
  end

  test "connected? returns false when no key_chain" do
    provider = providers(:one)
    key_chains(:openrouter).destroy!
    assert_not provider.reload.connected?
  end

  test "connected? accepts agent kwarg" do
    provider = providers(:one)
    assert provider.connected?(agent: agents(:one))
  end

  test "connected? works for chatgpt provider" do
    provider = providers(:chatgpt)
    assert provider.connected?
  end

  test "client raises for unknown provider name" do
    provider = Provider.new(name: "unknown")
    assert_raises(Providers::Error) { provider.client }
  end

  test "name uniqueness scoped to account" do
    provider = Provider.new(account: accounts(:one), name: "openrouter", model: "test")
    assert_not provider.valid?
    assert provider.errors[:name].any?
  end

  test "demote_existing_default scopes to account" do
    provider = providers(:one)
    assert provider.designation_default?

    openai = providers(:openai)
    openai.update!(designation: "default")
    assert openai.designation_default?
    assert provider.reload.designation_fallback?
  end
end
