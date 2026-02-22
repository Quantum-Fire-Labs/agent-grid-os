class AddOrchestratorToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :orchestrator, :boolean, default: false, null: false
  end
end
