class CreatePlugins < ActiveRecord::Migration[8.1]
  def change
    create_table :plugins do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :plugin_type, null: false, default: "tool"
      t.string :version, null: false, default: "1.0.0"
      t.text :description
      t.string :execution, null: false, default: "sandbox"
      t.string :entrypoint
      t.json :tools, default: []
      t.json :permissions, default: {}
      t.json :config_schema, default: []
      t.json :packages, default: []
      t.json :mounts, default: []
      t.timestamps
    end

    add_index :plugins, [ :account_id, :name ], unique: true
  end
end
