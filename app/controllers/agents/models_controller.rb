class Agents::ModelsController < ApplicationController
  include AgentAccessible

  before_action :set_agent
  before_action :require_agent_admin
  before_action :set_agent_model, only: %i[update destroy]

  def index
    @agent_models = @agent.agent_models.includes(:provider).order(:created_at)
    @available_providers = Current.account.providers
      .where.not(id: @agent.agent_models.select(:provider_id))
      .order(:created_at)
  end

  def create
    provider = Current.account.providers.find(params[:provider_id])
    @agent.agent_models.create!(
      provider: provider,
      model: params[:model].presence || provider.model,
      designation: params[:designation] || "fallback"
    )

    redirect_to agent_models_path(@agent), notice: "#{provider.display_name} added."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to agent_models_path(@agent), alert: e.message
  end

  def update
    @agent_model.update!(agent_model_params)
    redirect_to agent_models_path(@agent), notice: "#{@agent_model.provider.display_name} updated."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to agent_models_path(@agent), alert: e.message
  end

  def destroy
    name = @agent_model.provider.display_name
    @agent_model.destroy
    redirect_to agent_models_path(@agent), notice: "#{name} removed."
  end

  private
    def set_agent
      @agent = accessible_agents.find(params[:agent_id])
    end

    def set_agent_model
      @agent_model = @agent.agent_models.find(params[:id])
    end

    def agent_model_params
      params.permit(:designation, :model)
    end
end
