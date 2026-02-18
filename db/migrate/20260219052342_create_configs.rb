class CreateConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :configs do |t|
      t.references :configurable, polymorphic: true, null: false
      t.string :key, null: false
      t.string :value

      t.timestamps
    end

    add_index :configs, %i[configurable_type configurable_id key], unique: true
  end
end
