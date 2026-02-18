class CreateAgentProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_providers do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :provider, null: false, foreign_key: true
      t.string :designation, null: false, default: "none"
      t.timestamps
    end

    add_index :agent_providers, [ :agent_id, :provider_id ], unique: true
    add_index :agent_providers, [ :agent_id, :designation ]
  end
end
