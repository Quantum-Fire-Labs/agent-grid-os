class MakeMessagesConversationIdNullableForChatCutover < ActiveRecord::Migration[8.1]
  def up
    if sqlite?
      rebuild_messages_table_with_nullable_conversation_id
    else
      change_column_null :messages, :conversation_id, true
    end
  end

  def down
    if sqlite?
      rebuild_messages_table_with_not_null_conversation_id
    else
      change_column_null :messages, :conversation_id, false
    end
  end

  private
    def sqlite?
      connection.adapter_name.downcase.include?("sqlite")
    end

    def rebuild_messages_table_with_nullable_conversation_id
      execute <<~SQL
        CREATE TABLE messages_new (
          id integer PRIMARY KEY AUTOINCREMENT NOT NULL,
          chat_id integer,
          compacted_at datetime,
          content text,
          conversation_id integer,
          created_at datetime NOT NULL,
          role varchar NOT NULL,
          sender_id integer,
          sender_type varchar,
          tool_call_id varchar,
          tool_calls text,
          updated_at datetime NOT NULL,
          user_id integer
        )
      SQL

      execute <<~SQL
        INSERT INTO messages_new (
          id, chat_id, compacted_at, content, conversation_id, created_at, role,
          sender_id, sender_type, tool_call_id, tool_calls, updated_at, user_id
        )
        SELECT
          id, chat_id, compacted_at, content, conversation_id, created_at, role,
          sender_id, sender_type, tool_call_id, tool_calls, updated_at, user_id
        FROM messages
      SQL

      execute "DROP TABLE messages"
      execute "ALTER TABLE messages_new RENAME TO messages"

      add_index :messages, :chat_id
      add_index :messages, :conversation_id
      add_index :messages, [ :sender_type, :sender_id ]
      add_index :messages, :user_id
    end

    def rebuild_messages_table_with_not_null_conversation_id
      raise ActiveRecord::IrreversibleMigration, "Cannot restore NOT NULL conversation_id if null values were written"
    end
end
