class CustomApps::TransfersController < ApplicationController
  before_action :require_admin
  before_action :set_custom_app

  def create
    new_agent = Current.account.agents.find(params[:agent_id])
    @custom_app.transfer_to(new_agent)

    redirect_to custom_app_settings_path(@custom_app), notice: "#{@custom_app.name} transferred to #{new_agent.name}."
  end

  private
    def set_custom_app
      @custom_app = Current.account.custom_apps.find(params[:custom_app_id])
    end
end
