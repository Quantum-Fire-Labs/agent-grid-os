class Agents::TerminalsController < ApplicationController
  before_action :require_admin

  def show
    @agent = Current.account.agents.find(params[:agent_id])
  end
end
