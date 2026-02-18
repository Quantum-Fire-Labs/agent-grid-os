class CreatePluginConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :plugin_configs do |t|
      t.references :plugin, null: false, foreign_key: true
      t.references :configurable, polymorphic: true, null: false
      t.string :key, null: false
      t.string :value
      t.timestamps
    end

    add_index :plugin_configs,
      [ :plugin_id, :configurable_type, :configurable_id, :key ],
      unique: true, name: "idx_plugin_configs_unique"
  end
end
