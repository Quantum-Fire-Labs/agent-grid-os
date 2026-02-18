class CustomAppsController < ApplicationController
  include AgentAccessible

  content_security_policy only: :show do |policy|
    policy.script_src :self, :unsafe_inline
  end
  before_action :disable_csp_nonce, only: :show

  def index
    @custom_apps = CustomApp.published.where(agent: accessible_agents).includes(:agent)
  end

  def show
    @custom_app = CustomApp.published.where(agent: accessible_agents).find(params[:id])
    @content = @custom_app.entrypoint_content

    render layout: "custom_app"
  end

  def asset
    custom_app = CustomApp.published.where(agent: accessible_agents).find(params[:custom_app_id])
    file_path = custom_app.resolve_asset(params[:path])

    if file_path
      send_file file_path, disposition: :inline
    else
      head :not_found
    end
  end

  private

    def disable_csp_nonce
      request.content_security_policy_nonce_generator = nil
    end
end
