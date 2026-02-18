class CreateCustomTools < ActiveRecord::Migration[8.1]
  def change
    create_table :custom_tools do |t|
      t.references :agent, null: false, foreign_key: true
      t.string :name, null: false
      t.string :description, null: false
      t.json :parameter_schema, default: {}
      t.string :entrypoint, null: false
      t.timestamps
    end

    add_index :custom_tools, [ :agent_id, :name ], unique: true
  end
end
