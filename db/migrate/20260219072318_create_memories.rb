class CreateMemories < ActiveRecord::Migration[8.0]
  def change
    create_table :memories do |t|
      t.references :agent, null: false, foreign_key: true
      t.text :content, null: false
      t.binary :embedding
      t.string :source, null: false, default: "agent"
      t.string :state, null: false, default: "active"
      t.float :importance, null: false, default: 0.6
      t.integer :access_count, null: false, default: 0
      t.datetime :last_accessed_at
      t.datetime :demoted_at
      t.string :demotion_reason
      t.datetime :promoted_at
      t.integer :promoted_count, null: false, default: 0
      t.timestamps
    end

    add_index :memories, [ :agent_id, :state ]
    add_index :memories, [ :agent_id, :state, :created_at ]
  end
end
