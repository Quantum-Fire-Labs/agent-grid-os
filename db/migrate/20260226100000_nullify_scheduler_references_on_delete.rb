class NullifySchedulerReferencesOnDelete < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :scheduled_actions, :chats
    add_foreign_key :scheduled_actions, :chats, on_delete: :nullify

    remove_foreign_key :scheduled_actions, column: :created_from_message_id
    add_foreign_key :scheduled_actions, :messages, column: :created_from_message_id, on_delete: :nullify

    remove_foreign_key :scheduled_actions, column: :created_by_user_id
    add_foreign_key :scheduled_actions, :users, column: :created_by_user_id, on_delete: :nullify

    remove_foreign_key :scheduled_action_runs, column: :delivery_message_id
    add_foreign_key :scheduled_action_runs, :messages, column: :delivery_message_id, on_delete: :nullify
  end
end
