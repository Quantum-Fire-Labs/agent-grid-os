class Agents::CustomAppsController < ApplicationController
  before_action :require_admin
  before_action :set_agent

  def index
    @custom_apps = @agent.custom_apps.order(:slug)
  end

  private
    def set_agent
      @agent = Current.account.agents.find(params[:agent_id])
    end
end
