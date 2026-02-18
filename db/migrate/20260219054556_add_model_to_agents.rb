class AddModelToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :model, :string
  end
end
