class Agents::Plugins::ConfigsController < ApplicationController
  include AgentAccessible

  before_action :set_agent
  before_action :require_agent_admin
  before_action :set_plugin
  before_action :set_config, only: %i[update destroy]

  def index
    @configs = @plugin.plugin_configs.where(configurable: @agent)
    @account_configs = @plugin.plugin_configs.where(configurable: Current.account)
  end

  def create
    config = @plugin.plugin_configs.find_or_initialize_by(
      configurable: @agent,
      key: config_params[:key]
    )
    config.value = config_params[:value]

    if config.save
      redirect_to agent_plugin_configs_path(@agent, @plugin), notice: "Config saved."
    else
      redirect_to agent_plugin_configs_path(@agent, @plugin), alert: config.errors.full_messages.to_sentence
    end
  end

  def update
    if @config.update(value: config_params[:value])
      redirect_to agent_plugin_configs_path(@agent, @plugin), notice: "Config updated."
    else
      redirect_to agent_plugin_configs_path(@agent, @plugin), alert: @config.errors.full_messages.to_sentence
    end
  end

  def destroy
    @config.destroy
    redirect_to agent_plugin_configs_path(@agent, @plugin), notice: "Config removed."
  end

  private
    def set_agent
      @agent = accessible_agents.find(params[:agent_id])
    end

    def set_plugin
      @plugin = @agent.plugins.find(params[:plugin_id])
    end

    def set_config
      @config = @plugin.plugin_configs.where(configurable: @agent).find(params[:id])
    end

    def config_params
      params.expect(plugin_config: [ :key, :value ])
    end
end
