class AddWorkspaceEnabledToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :workspace_enabled, :boolean, default: false, null: false
  end
end
