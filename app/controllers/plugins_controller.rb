class PluginsController < ApplicationController
  before_action :require_admin

  def index
    @plugins = Current.account.plugins
  end

  def show
    @plugin = Current.account.plugins.find(params[:id])
  end

  def new
    @plugin = Plugin.new
  end

  def create
    plugin = Plugin.install_from(account: Current.account, source_path: params[:source_path])
    redirect_to plugin, notice: "#{plugin.name} installed."
  rescue Plugin::Installable::ManifestError => e
    redirect_back fallback_location: new_plugin_path, alert: e.message
  end

  def destroy
    @plugin = Current.account.plugins.find(params[:id])
    path = @plugin.path
    @plugin.destroy
    FileUtils.rm_rf(path)
    redirect_to plugins_path, notice: "#{@plugin.name} uninstalled."
  end
end
