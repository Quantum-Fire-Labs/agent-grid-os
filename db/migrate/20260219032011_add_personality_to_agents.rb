class AddPersonalityToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :personality, :text
  end
end
