require "test_helper"

class KeyChainTest < ActiveSupport::TestCase
  test "validates name presence" do
    kc = KeyChain.new(owner: accounts(:one), name: nil, secrets: {})
    assert_not kc.valid?
    assert kc.errors[:name].any?
  end

  test "validates uniqueness scoped to owner" do
    existing = key_chains(:openrouter)
    kc = KeyChain.new(owner: existing.owner, name: existing.name, secrets: {})
    assert_not kc.valid?
    assert kc.errors[:name].any?
  end

  test "allows same name for different owners" do
    kc = KeyChain.new(owner: accounts(:two), name: "openai", secrets: { "api_key" => "sk-new" })
    assert kc.valid?
  end

  test "api_key reader" do
    kc = key_chains(:openrouter)
    assert_equal "sk-test-123", kc.api_key
  end

  test "access_token reader" do
    kc = key_chains(:chatgpt)
    assert_equal "test-access-token", kc.access_token
  end

  test "refresh_token reader returns nil when absent" do
    kc = key_chains(:openrouter)
    assert_nil kc.refresh_token
  end

  test "oauth_account_id reader" do
    kc = key_chains(:chatgpt)
    assert_equal "test-account-id", kc.oauth_account_id
  end

  test "secrets returns nil values gracefully" do
    kc = KeyChain.new(owner: accounts(:one), name: "empty", secrets: {})
    assert_nil kc.api_key
    assert_nil kc.access_token
  end

  test "encrypts secrets column" do
    kc = KeyChain.create!(owner: accounts(:one), name: "encrypted_test", secrets: { "api_key" => "secret-value" })
    raw = KeyChain.connection.select_value("SELECT secrets FROM key_chains WHERE id = #{kc.id}")
    assert_not_includes raw.to_s, "secret-value"
  end
end
