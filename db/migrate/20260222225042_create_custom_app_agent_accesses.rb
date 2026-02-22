class CreateCustomAppAgentAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :custom_app_agent_accesses do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :custom_app, null: false, foreign_key: true

      t.timestamps
    end

    add_index :custom_app_agent_accesses, [ :agent_id, :custom_app_id ], unique: true
  end
end
