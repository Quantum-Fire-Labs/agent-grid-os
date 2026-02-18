class Settings::OauthConnectionsController < ApplicationController
  def create
    config = oauth_config_for(params[:provider_name])
    result = Providers::Oauth.start_device_auth(**config.slice(:client_id, :device_code_url))
    render json: result
  end

  def show
    key_chain = Current.account.key_chains.find_or_create_by!(name: params[:provider_name]) do |kc|
      kc.secrets = {}
    end
    config = oauth_config_for(params[:provider_name])
    result = Providers::Oauth.poll_device_auth(
      key_chain: key_chain,
      device_code: params[:device_code],
      user_code: params[:user_code],
      **config.slice(:client_id, :device_token_url, :token_url)
    )
    render json: result
  end

  def destroy
    key_chain = Current.account.key_chains.find_by!(name: params[:provider_name])
    key_chain.update!(secrets: {}, token_expires_at: nil)
    redirect_to settings_providers_path, notice: "Disconnected."
  end

  private
    def oauth_config_for(name)
      case name
      when "chatgpt" then Providers::ChatGpt::OAUTH_CONFIG
      else raise Providers::Error, "No OAuth config for provider: #{name}"
      end
    end
end
