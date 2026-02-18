class CreateProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :providers do |t|
      t.references :providerable, polymorphic: true, null: false
      t.string :name, null: false
      t.string :api_key
      t.string :model
      t.string :designation, default: "none", null: false

      t.timestamps
    end

    add_index :providers, %i[providerable_type providerable_id designation]
  end
end
