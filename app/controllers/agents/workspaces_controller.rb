class Agents::WorkspacesController < ApplicationController
  include AgentAccessible

  before_action :set_agent
  before_action :require_agent_admin

  def show
    respond_to do |format|
      format.html
      format.json do
        workspace = Agent::Workspace.new(@agent)
        if params[:file].present?
          render json: { content: workspace.read_file(params[:path]) }
        else
          render json: workspace.list(params[:path] || ".")
        end
      end
    end
  end

  def update
    if params[:workspace].key?(:network_mode)
      @agent.update!(network_mode: params[:workspace][:network_mode])
      redirect_to agent_workspace_path(@agent), notice: "Network mode updated."
    else
      enabled = params[:workspace][:enabled] == "1"
      @agent.update!(workspace_enabled: enabled)

      if enabled
        Agent::Workspace.new(@agent).start
      else
        Agent::Workspace.new(@agent).stop
      end

      redirect_to agent_workspace_path(@agent), notice: "Workspace #{enabled ? 'enabled' : 'disabled'}."
    end
  end

  def create
    workspace = Agent::Workspace.new(@agent)
    entry = params.expect(entry: [ :name, :type, :path ])

    full_path = File.join(entry[:path].presence || ".", entry[:name])
    safe_path = workspace.sanitized_path(full_path)

    if entry[:type] == "directory"
      workspace.exec("mkdir -p #{Shellwords.shellescape(safe_path)}")
    else
      workspace.exec("mkdir -p #{Shellwords.shellescape(File.dirname(safe_path))} && touch #{Shellwords.shellescape(safe_path)}")
    end

    respond_to do |format|
      format.json { render json: { ok: true } }
      format.html { redirect_to agent_workspace_path(@agent), notice: "#{entry[:type].capitalize} created." }
    end
  end

  private
    def set_agent
      @agent = accessible_agents.find(params[:agent_id])
    end
end
