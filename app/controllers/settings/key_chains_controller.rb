class Settings::KeyChainsController < ApplicationController
  before_action :require_admin
  before_action :set_key_chain, only: %i[edit update destroy]

  def index
    @key_chains = Current.account.key_chains.where(token_expires_at: nil).order(:name)
  end

  def new
    @key_chain = Current.account.key_chains.new
  end

  def create
    @key_chain = Current.account.key_chains.new(key_chain_params.except(:secret))
    @key_chain.secrets = { "api_key" => params.dig(:key_chain, :secret) }

    @key_chain.save!
    redirect_to settings_key_chains_path, notice: "Keychain added."
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
    redirect_to settings_key_chains_path, notice: "Keychain updated."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @key_chain.destroy
    redirect_to settings_key_chains_path, notice: "Keychain removed."
  end

  private
    def set_key_chain
      @key_chain = Current.account.key_chains.find(params[:id])
    end

    def key_chain_params
      params.expect(key_chain: [ :name, :secret, :sandbox_accessible ])
    end
end
