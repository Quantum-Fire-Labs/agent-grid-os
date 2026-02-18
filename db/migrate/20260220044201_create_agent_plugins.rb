class CreateAgentPlugins < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_plugins do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :plugin, null: false, foreign_key: true
      t.timestamps
    end

    add_index :agent_plugins, [ :agent_id, :plugin_id ], unique: true
  end
end
