class Agents::UsersController < ApplicationController
  before_action :require_admin
  before_action :set_agent

  def index
    @agent_users = @agent.agent_users.includes(:user).order("users.first_name")
    @available_users = Current.account.users.where.not(id: @agent.user_ids).order(:first_name)
  end

  def create
    user = Current.account.users.find(params[:user_id])
    @agent.agent_users.create!(user: user)
    redirect_to agent_users_path(@agent), notice: "#{user.first_name} added."
  end

  def destroy
    agent_user = @agent.agent_users.find(params[:id])
    name = agent_user.user.first_name
    agent_user.destroy
    redirect_to agent_users_path(@agent), notice: "#{name} removed."
  end

  private
    def set_agent
      @agent = Current.account.agents.find(params[:agent_id])
    end
end
