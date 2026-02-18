class Settings::ProvidersController < ApplicationController
  before_action :require_admin
  before_action :set_provider, only: %i[edit update destroy]

  def index
    @providers = Current.account.providers.order(:created_at)
  end

  def new
    @provider = Current.account.providers.new
  end

  def create
    @provider = Current.account.providers.new(provider_params)

    ActiveRecord::Base.transaction do
      @provider.save!
      if api_key_param.present?
        Current.account.key_chains.find_or_initialize_by(name: @provider.name).tap do |kc|
          kc.secrets = (kc.secrets || {}).merge("api_key" => api_key_param)
          kc.save!
        end
      end
    end

    redirect_to settings_providers_path, notice: "Provider added."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    filtered = provider_params

    ActiveRecord::Base.transaction do
      @provider.update!(filtered)
      if api_key_param.present?
        Current.account.key_chains.find_or_initialize_by(name: @provider.name).tap do |kc|
          kc.secrets = (kc.secrets || {}).merge("api_key" => api_key_param)
          kc.save!
        end
      end
    end

    redirect_to settings_providers_path, notice: "Provider updated."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @provider.destroy
    redirect_to settings_providers_path, notice: "Provider removed."
  end

  private
    def set_provider
      @provider = Current.account.providers.find(params[:id])
    end

    def provider_params
      params.expect(provider: [ :name, :model, :designation ])
    end

    def api_key_param
      params.dig(:provider, :api_key)
    end
end
