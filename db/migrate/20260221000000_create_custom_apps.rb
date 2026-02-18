class CreateCustomApps < ActiveRecord::Migration[8.1]
  def change
    create_table :custom_apps do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :icon_emoji
      t.string :path, null: false
      t.string :entrypoint, default: "index.html"
      t.string :status, default: "published"
      t.timestamps
    end

    add_index :custom_apps, [ :account_id, :name ], unique: true
  end
end
