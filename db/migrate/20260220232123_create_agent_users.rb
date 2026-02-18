class CreateAgentUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_users do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps

      t.index %i[agent_id user_id], unique: true
    end
  end
end
