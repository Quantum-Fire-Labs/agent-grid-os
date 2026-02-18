require "test_helper"

class Providers::OauthTest < ActiveSupport::TestCase
  test "ensure_fresh_token skips when no refresh_token" do
    kc = key_chains(:openrouter)  # has no refresh_token
    original_token = kc.api_key
    Providers::Oauth.ensure_fresh_token(key_chain: kc, client_id: "test", token_url: "https://example.com/token")
    assert_equal original_token, kc.reload.api_key
  end

  test "ensure_fresh_token skips when no token_expires_at" do
    kc = key_chains(:chatgpt)
    kc.update!(secrets: kc.secrets.merge("refresh_token" => "rt-test"), token_expires_at: nil)
    original_token = kc.access_token
    Providers::Oauth.ensure_fresh_token(key_chain: kc, client_id: "test", token_url: "https://example.com/token")
    assert_equal original_token, kc.reload.access_token
  end

  test "ensure_fresh_token skips when token not expiring soon" do
    kc = key_chains(:chatgpt)
    kc.update!(
      secrets: kc.secrets.merge("refresh_token" => "rt-test"),
      token_expires_at: 30.minutes.from_now
    )
    original_token = kc.access_token
    Providers::Oauth.ensure_fresh_token(key_chain: kc, client_id: "test", token_url: "https://example.com/token")
    assert_equal original_token, kc.reload.access_token
  end

  test "extract_account_id parses JWT" do
    # Build a minimal JWT with account_id in the auth claim
    payload = { "https://api.openai.com/auth" => { "account_id" => "acct_123" } }
    jwt = "header.#{Base64.urlsafe_encode64(payload.to_json, padding: false)}.signature"

    result = Providers::Oauth.extract_account_id(jwt)
    assert_equal "acct_123", result
  end

  test "extract_account_id returns nil for invalid JWT" do
    assert_nil Providers::Oauth.extract_account_id("not-a-jwt")
  end

  test "extract_account_id returns nil for nil" do
    assert_nil Providers::Oauth.extract_account_id(nil)
  end
end
