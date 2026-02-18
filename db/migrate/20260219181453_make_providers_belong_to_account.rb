class MakeProvidersBelongToAccount < ActiveRecord::Migration[8.1]
  def up
    # Remove any agent-owned providers (agents now use the join table instead)
    execute "DELETE FROM providers WHERE providerable_type != 'Account'"

    add_reference :providers, :account, foreign_key: true
    execute "UPDATE providers SET account_id = providerable_id"
    change_column_null :providers, :account_id, false

    remove_index :providers, name: "index_providers_on_providerable"
    remove_index :providers, name: "idx_on_providerable_type_providerable_id_designatio_0676b53a36"
    remove_column :providers, :providerable_type, :string
    remove_column :providers, :providerable_id, :integer

    add_index :providers, [ :account_id, :name ], unique: true
    add_index :providers, [ :account_id, :designation ]
  end

  def down
    remove_index :providers, [ :account_id, :name ]
    remove_index :providers, [ :account_id, :designation ]

    add_column :providers, :providerable_type, :string
    add_column :providers, :providerable_id, :integer

    execute "UPDATE providers SET providerable_type = 'Account', providerable_id = account_id"

    change_column_null :providers, :providerable_type, false
    change_column_null :providers, :providerable_id, false

    add_index :providers, [ :providerable_type, :providerable_id ], name: "index_providers_on_providerable"
    add_index :providers, [ :providerable_type, :providerable_id, :designation ], name: "idx_on_providerable_type_providerable_id_designatio_0676b53a36"

    remove_reference :providers, :account
  end
end
