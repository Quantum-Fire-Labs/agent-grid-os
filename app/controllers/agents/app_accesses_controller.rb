class Agents::AppAccessesController < ApplicationController
  before_action :require_admin
  before_action :set_agent

  def index
    @granted_apps = @agent.granted_apps.includes(:agent)
    @available_apps = Current.account.custom_apps.includes(:agent).where.not(agent: @agent).where.not(id: @agent.granted_app_ids)
  end

  def create
    app = Current.account.custom_apps.find(params[:custom_app_id])
    access = @agent.custom_app_agent_accesses.build(custom_app: app)

    if access.save
      redirect_to agent_app_accesses_path(@agent), notice: "Access granted to #{app.name}."
    else
      redirect_to agent_app_accesses_path(@agent), alert: access.errors.full_messages.to_sentence
    end
  end

  def destroy
    access = @agent.custom_app_agent_accesses.find(params[:id])
    name = access.custom_app.name
    access.destroy
    redirect_to agent_app_accesses_path(@agent), notice: "Access to #{name} revoked."
  end

  private
    def set_agent
      @agent = Current.account.agents.find(params[:agent_id])
    end
end
