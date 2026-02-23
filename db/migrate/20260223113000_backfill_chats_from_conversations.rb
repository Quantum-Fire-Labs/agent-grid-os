class BackfillChatsFromConversations < ActiveRecord::Migration[8.1]
  class LegacyConversation < ActiveRecord::Base
    self.table_name = "conversations"
  end

  class LegacyParticipant < ActiveRecord::Base
    self.table_name = "participants"
  end

  class LegacyMessage < ActiveRecord::Base
    self.table_name = "messages"
  end

  class LegacyAgent < ActiveRecord::Base
    self.table_name = "agents"
  end

  class LegacyUser < ActiveRecord::Base
    self.table_name = "users"
  end

  class ChatRow < ActiveRecord::Base
    self.table_name = "chats"
  end

  def up
    LegacyConversation.reset_column_information
    LegacyParticipant.reset_column_information
    LegacyMessage.reset_column_information
    ChatRow.reset_column_information

    agent_account_ids = LegacyAgent.pluck(:id, :account_id).to_h
    user_account_ids = LegacyUser.pluck(:id, :account_id).to_h

    say_with_time "Backfilling chats from conversations" do
      LegacyConversation.find_each do |conversation|
        chat = ChatRow.create!(
          account_id: account_id_for(conversation, agent_account_ids, user_account_ids),
          title: nil,
          created_at: conversation.created_at,
          updated_at: conversation.updated_at
        )

        LegacyParticipant.where(conversation_id: conversation.id).find_each do |participant|
          participant.update!(
            chat_id: chat.id,
            participatable_type: "User",
            participatable_id: participant.user_id
          )
        end

        add_agent_participant!(chat, conversation)

        LegacyMessage.where(conversation_id: conversation.id).find_each do |message|
          attrs = { chat_id: chat.id }

          if message.user_id.present?
            attrs[:sender_type] = "User"
            attrs[:sender_id] = message.user_id
          elsif conversation.agent_id.present? && %w[assistant tool].include?(message.role)
            attrs[:sender_type] = "Agent"
            attrs[:sender_id] = conversation.agent_id
          end

          message.update!(attrs)
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private
    def account_id_for(conversation, agent_account_ids, user_account_ids)
      return agent_account_ids[conversation.agent_id] if conversation.agent_id.present?

      user_id = LegacyParticipant.where(conversation_id: conversation.id).where.not(user_id: nil).pick(:user_id)
      account_id = user_account_ids[user_id]
      return account_id if account_id.present?

      raise "Could not determine account for conversation #{conversation.id}"
    end

    def add_agent_participant!(chat, conversation)
      return unless conversation.agent_id.present?

      existing = LegacyParticipant.exists?(
        chat_id: chat.id,
        participatable_type: "Agent",
        participatable_id: conversation.agent_id
      )
      return if existing

      LegacyParticipant.create!(
        chat_id: chat.id,
        conversation_id: conversation.id,
        participatable_type: "Agent",
        participatable_id: conversation.agent_id,
        user_id: nil
      )
    end
end
