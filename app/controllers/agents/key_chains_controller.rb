class Agents::KeyChainsController < ApplicationController
  include AgentAccessible

  before_action :set_agent
  before_action :require_agent_admin
  before_action :set_key_chain, only: %i[edit update destroy]

  def index
    @key_chains = @agent.key_chains.order(:name)
    @account_key_chains = Current.account.key_chains.where(token_expires_at: nil).order(:name)
  end

  def new
    @key_chain = @agent.key_chains.new
  end

  def create
    @key_chain = @agent.key_chains.new(key_chain_params.except(:secret))
    @key_chain.secrets = { "api_key" => params.dig(:key_chain, :secret) }

    @key_chain.save!
    redirect_to agent_key_chains_path(@agent), notice: "Keychain added. Reboot the agent to apply changes."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    @key_chain.assign_attributes(key_chain_params.except(:secret))
    if params.dig(:key_chain, :secret).present?
      @key_chain.secrets = (@key_chain.secrets || {}).merge("api_key" => params.dig(:key_chain, :secret))
    end

    @key_chain.save!
    redirect_to agent_key_chains_path(@agent), notice: "Keychain updated. Reboot the agent to apply changes."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @key_chain.destroy
    redirect_to agent_key_chains_path(@agent), notice: "Keychain removed. Reboot the agent to apply changes."
  end

  private
    def set_agent
      @agent = accessible_agents.find(params[:agent_id])
    end

    def set_key_chain
      @key_chain = @agent.key_chains.find(params[:id])
    end

    def key_chain_params
      params.expect(key_chain: [ :name, :secret, :sandbox_accessible ])
    end
end
