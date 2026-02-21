class AddInstructionsToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :instructions, :text
  end
end
