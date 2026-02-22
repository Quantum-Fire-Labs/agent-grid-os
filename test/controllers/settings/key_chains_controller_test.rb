require "test_helper"

class Settings::KeyChainsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    post session_url, params: { email_address: @user.email_address, password: "password" }
  end

  test "index shows account keychains" do
    get settings_key_chains_url
    assert_response :success
    assert_select ".provider-row"
  end

  test "index excludes OAuth keychains with token_expires_at" do
    kc = @account.key_chains.create!(name: "oauth_temp", secrets: { "api_key" => "x" }, token_expires_at: 1.hour.from_now)
    get settings_key_chains_url
    assert_response :success
    assert_no_match "oauth_temp", response.body
  end

  test "new renders form" do
    get new_settings_key_chain_url
    assert_response :success
    assert_select "form"
  end

  test "create adds keychain" do
    assert_difference -> { @account.key_chains.count }, 1 do
      post settings_key_chains_url, params: { key_chain: { name: "NEW_KEY", secret: "supersecret", sandbox_accessible: true } }
    end
    assert_redirected_to settings_key_chains_url

    kc = @account.key_chains.find_by(name: "NEW_KEY")
    assert_equal "supersecret", kc.api_key
    assert kc.sandbox_accessible?
  end

  test "create with invalid params re-renders form" do
    post settings_key_chains_url, params: { key_chain: { name: "", secret: "x" } }
    assert_response :unprocessable_entity
  end

  test "edit renders form" do
    kc = key_chains(:account_sandbox_key)
    get edit_settings_key_chain_url(kc)
    assert_response :success
    assert_select "form"
  end

  test "update changes keychain" do
    kc = key_chains(:account_sandbox_key)
    patch settings_key_chain_url(kc), params: { key_chain: { name: "RENAMED_KEY", secret: "", sandbox_accessible: false } }
    assert_redirected_to settings_key_chains_url

    kc.reload
    assert_equal "RENAMED_KEY", kc.name
    assert_equal "secret-account-value", kc.api_key
    assert_not kc.sandbox_accessible?
  end

  test "update with new secret replaces it" do
    kc = key_chains(:account_sandbox_key)
    patch settings_key_chain_url(kc), params: { key_chain: { name: kc.name, secret: "new-secret" } }
    assert_redirected_to settings_key_chains_url

    assert_equal "new-secret", kc.reload.api_key
  end

  test "destroy removes keychain" do
    kc = key_chains(:account_sandbox_key)
    assert_difference -> { @account.key_chains.count }, -1 do
      delete settings_key_chain_url(kc)
    end
    assert_redirected_to settings_key_chains_url
  end

  test "non-admin is redirected" do
    delete session_url
    member = users(:teammate)
    post session_url, params: { email_address: member.email_address, password: "password" }

    get settings_key_chains_url
    assert_response :redirect
  end
end
