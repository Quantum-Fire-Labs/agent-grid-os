class CreateKeyChains < ActiveRecord::Migration[8.1]
  def change
    create_table :key_chains do |t|
      t.string :owner_type, null: false
      t.integer :owner_id, null: false
      t.string :name, null: false
      t.text :secrets
      t.datetime :token_expires_at
      t.boolean :sandbox_accessible, default: false, null: false
      t.timestamps
    end
    add_index :key_chains, [ :owner_type, :owner_id, :name ], unique: true
  end
end
