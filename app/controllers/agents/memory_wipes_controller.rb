class Agents::MemoryWipesController < ApplicationController
  include AgentAccessible

  before_action :set_agent
  before_action :require_agent_admin

  def new
  end

  def create
    cutoff = resolve_cutoff
    @agent.wipe_memory(since: cutoff)
    redirect_to @agent, notice: "#{@agent.name}'s memory has been wiped."
  end

  private
    def set_agent
      @agent = accessible_agents.find(params[:agent_id])
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
