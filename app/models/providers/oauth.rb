require "net/http"
require "json"

module Providers::Oauth
  module_function

  def start_device_auth(client_id:, device_code_url:)
    uri = URI(device_code_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request.body = { client_id: client_id, scope: "openid profile email offline_access" }.to_json

    response = http.request(request)
    data = JSON.parse(response.body)

    unless response.is_a?(Net::HTTPSuccess)
      raise Providers::Error, data["error_description"] || "Failed to start device auth"
    end

    {
      device_code: data["device_auth_id"] || data["device_code"],
      user_code: data["user_code"],
      verification_uri: "https://auth.openai.com/codex/device",
      expires_in: data["expires_in"],
      interval: (data["interval"] || 5).to_i
    }
  end

  def poll_device_auth(key_chain:, device_code:, user_code:, client_id:, device_token_url:, token_url:)
    # Step 1: Poll for authorization_code
    uri = URI(device_token_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request.body = { device_auth_id: device_code, user_code: user_code }.to_json

    response = http.request(request)
    return { status: "pending" } unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)

    auth_code = data["authorization_code"]
    code_verifier = data["code_verifier"]
    return { status: "pending" } unless auth_code.present?

    # Step 2: Exchange authorization_code for tokens
    tokens = exchange_tokens(
      auth_code: auth_code,
      code_verifier: code_verifier,
      client_id: client_id,
      token_url: token_url
    )
    return { status: "pending" } unless tokens

    account_id = extract_account_id(tokens["access_token"])

    key_chain.update!(
      secrets: (key_chain.secrets || {}).merge(
        "access_token" => tokens["access_token"],
        "refresh_token" => tokens["refresh_token"],
        "oauth_account_id" => account_id
      ),
      token_expires_at: tokens["expires_in"] ? Time.current + tokens["expires_in"].seconds : nil
    )

    { status: "connected" }
  end

  def exchange_tokens(auth_code:, code_verifier:, client_id:, token_url:)
    uri = URI(token_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request.body = URI.encode_www_form(
      grant_type: "authorization_code",
      code: auth_code,
      redirect_uri: "https://auth.openai.com/deviceauth/callback",
      client_id: client_id,
      code_verifier: code_verifier
    )

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    return nil unless data["access_token"].present?

    data
  rescue StandardError
    nil
  end

  def ensure_fresh_token(key_chain:, client_id:, token_url:)
    return unless key_chain.refresh_token.present?
    return unless key_chain.token_expires_at.present?
    return unless key_chain.token_expires_at < 5.minutes.from_now

    uri = URI(token_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request.body = {
      client_id: client_id,
      grant_type: "refresh_token",
      refresh_token: key_chain.refresh_token
    }.to_json

    response = http.request(request)
    data = JSON.parse(response.body)

    if data["error"]
      raise Providers::Error, "Token refresh failed: #{data["error_description"] || data["error"]}"
    end

    expires_in = data["expires_in"]
    key_chain.update!(
      secrets: key_chain.secrets.merge(
        "access_token" => data["access_token"],
        "refresh_token" => data["refresh_token"] || key_chain.refresh_token
      ),
      token_expires_at: expires_in ? Time.current + expires_in.seconds : nil
    )
  end

  def extract_account_id(jwt)
    payload = jwt.split(".")[1]
    return nil unless payload
    decoded = JSON.parse(Base64.urlsafe_decode64(payload + "=" * (-payload.length % 4)))
    decoded["https://api.openai.com/auth"]&.dig("account_id") ||
      decoded["https://api.openai.com/profile"]&.dig("account_id")
  rescue
    nil
  end
end
