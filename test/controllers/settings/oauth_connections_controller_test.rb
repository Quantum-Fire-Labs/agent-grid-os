require "test_helper"

class Settings::OauthConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "destroy clears key_chain secrets and redirects" do
    key_chains(:chatgpt)  # ensure fixture exists

    delete settings_oauth_connection_path(provider_name: "chatgpt")

    assert_redirected_to settings_providers_path
    kc = KeyChain.find_by(owner: accounts(:one), name: "chatgpt")
    assert_equal({}, kc.secrets)
    assert_nil kc.token_expires_at
  end
end
