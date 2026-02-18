class Plugins::ConfigsController < ApplicationController
  before_action :require_admin
  before_action :set_plugin
  before_action :set_config, only: %i[update destroy]

  def index
    @configs = @plugin.plugin_configs.where(configurable: Current.account)
  end

  def create
    config = @plugin.plugin_configs.find_or_initialize_by(
      configurable: Current.account,
      key: params[:key]
    )
    config.value = params[:value]

    if config.save
      redirect_to plugin_configs_path(@plugin), notice: "Config saved."
    else
      redirect_to plugin_configs_path(@plugin), alert: config.errors.full_messages.to_sentence
    end
  end

  def update
    if @config.update(value: params[:value])
      redirect_to plugin_configs_path(@plugin), notice: "Config updated."
    else
      redirect_to plugin_configs_path(@plugin), alert: @config.errors.full_messages.to_sentence
    end
  end

  def destroy
    @config.destroy
    redirect_to plugin_configs_path(@plugin), notice: "Config removed."
  end

  private
    def set_plugin
      @plugin = Current.account.plugins.find(params[:plugin_id])
    end

    def set_config
      @config = @plugin.plugin_configs.where(configurable: Current.account).find(params[:id])
    end
end
