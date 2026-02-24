class Agents::AwakeningsController < ApplicationController
  include AgentAccessible

  before_action :set_agent
  before_action :require_agent_admin

  def create
    @agent.running!
    Agent::Workspace.new(@agent).start if @agent.workspace_enabled?
    redirect_to @agent
  end

  def update
    workspace = Agent::Workspace.new(@agent)
    if @agent.workspace_enabled?
      workspace.destroy
    end
    @agent.asleep!
    @agent.running!
    workspace.start if @agent.workspace_enabled?
    redirect_to @agent, notice: "#{@agent.name} rebooted."
  end

  def destroy
    Agent::Workspace.new(@agent).stop if @agent.workspace_enabled?
    @agent.asleep!
    redirect_to @agent
  end

  private

    def set_agent
      @agent = accessible_agents.find(params[:agent_id])
    end
end
