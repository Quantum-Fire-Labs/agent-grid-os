class Agents::PluginsController < ApplicationController
  include AgentAccessible

  before_action :set_agent
  before_action :require_agent_admin

  def index
    @enabled_plugins = @agent.plugins
    @available_plugins = Current.account.plugins.where.not(id: @agent.plugin_ids)
  end

  def create
    plugin = Current.account.plugins.find(params[:plugin_id])
    agent_plugin = @agent.agent_plugins.build(plugin: plugin)

    if agent_plugin.save
      redirect_to agent_plugins_path(@agent), notice: "#{plugin.name} enabled."
    else
      redirect_to agent_plugins_path(@agent), alert: agent_plugin.errors.full_messages.to_sentence
    end
  end

  def destroy
    agent_plugin = @agent.agent_plugins.find(params[:id])
    name = agent_plugin.plugin.name
    agent_plugin.destroy
    redirect_to agent_plugins_path(@agent), notice: "#{name} disabled."
  end

  private
    def set_agent
      @agent = accessible_agents.find(params[:agent_id])
    end
end
