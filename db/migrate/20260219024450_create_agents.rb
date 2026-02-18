class CreateAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :agents do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name
      t.string :title
      t.text :description
      t.string :status
      t.string :network_mode

      t.timestamps
    end
  end
end
