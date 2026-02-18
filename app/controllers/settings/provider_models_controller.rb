class Settings::ProviderModelsController < ApplicationController
  before_action :require_admin

  def index
    client_class = Provider::CLIENTS[params[:provider_name]]
    return render json: [] unless client_class

    key_chain = Current.account.key_chains.find_by(name: params[:provider_name])
    render json: client_class.models(key_chain)
  rescue StandardError
    render json: []
  end
end
