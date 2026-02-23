class Agents::FactoryResetsController < ApplicationController
  before_action :require_admin
  before_action :set_agent

  def create
    @agent.factory_reset
    redirect_to @agent, notice: "#{@agent.name} has been factory reset."
  end

  private
    def set_agent
      @agent = Current.account.agents.find(params[:agent_id])
    end
end
