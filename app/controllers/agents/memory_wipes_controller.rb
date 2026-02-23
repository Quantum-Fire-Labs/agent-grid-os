class Agents::MemoryWipesController < ApplicationController
  before_action :require_admin
  before_action :set_agent

  def new
  end

  def create
    cutoff = resolve_cutoff
    @agent.wipe_memory(since: cutoff)
    redirect_to @agent, notice: "#{@agent.name}'s memory has been wiped."
  end

  private
    def set_agent
      @agent = Current.account.agents.find(params[:agent_id])
    end

    def resolve_cutoff
      return nil if params.expect(:scope) == "everything"

      amount = params.expect(:amount).to_i
      unit = params.expect(:unit)
      raise ActionController::BadRequest, "Amount must be positive" unless amount > 0

      duration = case unit
      when "minutes" then amount.minutes
      when "hours"   then amount.hours
      when "days"    then amount.days
      when "weeks"   then amount.weeks
      else raise ActionController::BadRequest, "Invalid unit"
      end

      duration.ago
    end
end
