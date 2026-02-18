class CreateSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :skills do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.text :body

      t.timestamps
    end
  end
end
