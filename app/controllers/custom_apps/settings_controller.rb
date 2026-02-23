class CustomApps::SettingsController < ApplicationController
  before_action :require_admin

  def show
    @custom_app = Current.account.custom_apps.find(params[:custom_app_id])
    @custom_app_users = @custom_app.custom_app_users.includes(:user).order("users.first_name")
    @available_users = Current.account.users.where.not(id: @custom_app.user_ids).order(:first_name)
    @agent_accesses = @custom_app.custom_app_agent_accesses.includes(:agent).order("agents.name")
    granted_agent_ids = @agent_accesses.map(&:agent_id) + [ @custom_app.agent_id ]
    @available_agents = Current.account.agents.where.not(id: granted_agent_ids).order(:name)
    @transfer_agents = Current.account.agents.where.not(id: @custom_app.agent_id).order(:name)
  end
end
