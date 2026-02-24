class Agents::CustomAppsController < ApplicationController
  include AgentAccessible

  before_action :set_agent
  before_action :require_agent_admin

  def index
    @custom_apps = @agent.custom_apps.order(:slug)
  end

  private
    def set_agent
      @agent = accessible_agents.find(params[:agent_id])
    end
end
