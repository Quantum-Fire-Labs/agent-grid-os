class Agents::TerminalsController < ApplicationController
  include AgentAccessible

  before_action :set_agent
  before_action :require_agent_admin

  def show
  end

  private
    def set_agent
      @agent = accessible_agents.find(params[:agent_id])
    end
end
