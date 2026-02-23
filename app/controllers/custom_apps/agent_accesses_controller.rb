class CustomApps::AgentAccessesController < ApplicationController
  before_action :require_admin
  before_action :set_custom_app

  def create
    agent = Current.account.agents.find(params[:agent_id])
    @custom_app.custom_app_agent_accesses.create!(agent: agent)
    redirect_to custom_app_settings_path(@custom_app), notice: "#{agent.name} granted access."
  end

  def destroy
    access = @custom_app.custom_app_agent_accesses.find(params[:id])
    name = access.agent.name
    access.destroy
    redirect_to custom_app_settings_path(@custom_app), notice: "#{name} access removed."
  end

  private
    def set_custom_app
      @custom_app = Current.account.custom_apps.find(params[:custom_app_id])
    end
end
