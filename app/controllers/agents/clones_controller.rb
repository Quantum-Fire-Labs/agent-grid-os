class Agents::ClonesController < ApplicationController
  before_action :require_admin
  before_action :set_agent

  def new
  end

  def create
    name = params.expect(:name)
    include_memories = params[:include_memories] == "1"
    clone = @agent.duplicate(name: name, include_memories: include_memories)
    redirect_to clone, notice: "#{clone.name} has been created."
  end

  private
    def set_agent
      @agent = Current.account.agents.find(params[:agent_id])
    end
end
