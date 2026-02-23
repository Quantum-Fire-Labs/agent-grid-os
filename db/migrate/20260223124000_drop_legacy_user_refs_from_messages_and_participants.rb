class DropLegacyUserRefsFromMessagesAndParticipants < ActiveRecord::Migration[8.1]
  def up
    if sqlite?
      rebuild_participants_without_user_id if column_exists?(:participants, :user_id)
      rebuild_messages_without_user_id if column_exists?(:messages, :user_id)
    else
      remove_column :participants, :user_id if column_exists?(:participants, :user_id)
      remove_column :messages, :user_id if column_exists?(:messages, :user_id)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private
    def sqlite?
      connection.adapter_name.downcase.include?("sqlite")
    end

    def rebuild_participants_without_user_id
      execute <<~SQL
        CREATE TABLE participants_new (
          id integer PRIMARY KEY AUTOINCREMENT NOT NULL,
          chat_id integer,
          created_at datetime NOT NULL,
          participatable_id integer,
          participatable_type varchar,
          updated_at datetime NOT NULL
        )
      SQL

      execute <<~SQL
        INSERT INTO participants_new (
          id, chat_id, created_at, participatable_id, participatable_type, updated_at
        )
        SELECT
          id, chat_id, created_at, participatable_id, participatable_type, updated_at
        FROM participants
      SQL

      execute "DROP TABLE participants"
      execute "ALTER TABLE participants_new RENAME TO participants"

      add_index :participants, [ :chat_id, :participatable_type, :participatable_id ],
        unique: true,
        name: "idx_participants_chat_and_participatable_unique"
      add_index :participants, :chat_id
      add_index :participants, [ :participatable_type, :participatable_id ]
    end

    def rebuild_messages_without_user_id
      execute <<~SQL
        CREATE TABLE messages_new (
          id integer PRIMARY KEY AUTOINCREMENT NOT NULL,
          chat_id integer,
          compacted_at datetime,
          content text,
          created_at datetime NOT NULL,
          role varchar NOT NULL,
          sender_id integer,
          sender_type varchar,
          tool_call_id varchar,
          tool_calls text,
          updated_at datetime NOT NULL
        )
      SQL

      execute <<~SQL
        INSERT INTO messages_new (
          id, chat_id, compacted_at, content, created_at, role, sender_id, sender_type,
          tool_call_id, tool_calls, updated_at
        )
        SELECT
          id, chat_id, compacted_at, content, created_at, role, sender_id, sender_type,
          tool_call_id, tool_calls, updated_at
        FROM messages
      SQL

      execute "DROP TABLE messages"
      execute "ALTER TABLE messages_new RENAME TO messages"

      add_index :messages, :chat_id
      add_index :messages, [ :sender_type, :sender_id ]
    end
end
