class Agents::FactoryResetsController < ApplicationController
  include AgentAccessible

  before_action :set_agent
  before_action :require_agent_admin

  def create
    @agent.factory_reset
    redirect_to @agent, notice: "#{@agent.name} has been factory reset."
  end

  private
    def set_agent
      @agent = accessible_agents.find(params[:agent_id])
    end
end
