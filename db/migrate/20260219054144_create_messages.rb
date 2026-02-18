class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content
      t.text :tool_calls
      t.string :tool_call_id

      t.timestamps
    end
  end
end
