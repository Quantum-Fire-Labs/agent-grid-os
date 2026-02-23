class CreateCustomAppUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :custom_app_users do |t|
      t.references :custom_app, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :custom_app_users, [ :custom_app_id, :user_id ], unique: true
  end
end
