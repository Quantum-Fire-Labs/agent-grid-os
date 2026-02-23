class AddChatsAndPolymorphicChatRefs < ActiveRecord::Migration[8.1]
  def change
    create_table :chats do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title

      t.timestamps
    end

    change_column_null :conversations, :agent_id, true

    add_column :participants, :chat_id, :integer
    add_column :participants, :participatable_type, :string
    add_column :participants, :participatable_id, :integer

    add_index :participants, :chat_id
    add_index :participants, [ :participatable_type, :participatable_id ]
    add_index :participants, [ :chat_id, :participatable_type, :participatable_id ],
      unique: true,
      name: "idx_participants_chat_and_participatable_unique"

    add_column :messages, :chat_id, :integer
    add_column :messages, :sender_type, :string
    add_column :messages, :sender_id, :integer

    add_index :messages, :chat_id
    add_index :messages, [ :sender_type, :sender_id ]
  end
end
