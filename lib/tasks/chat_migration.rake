namespace :chat do
  namespace :migration do
    desc "Validate Conversation -> Chat backfill invariants"
    task validate_backfill: :environment do
      unless ActiveRecord::Base.connection.data_source_exists?("conversations")
        puts "Skipping backfill validation: conversations table has been removed."
        next
      end

      failures = []

      chats_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM chats").to_i
      conversations_count = Conversation.count
      failures << "Expected chats count (#{chats_count}) to be >= conversations count (#{conversations_count})" if chats_count < conversations_count

      participants_missing_chat = Participant.where(chat_id: nil).count
      failures << "Participants missing chat_id: #{participants_missing_chat}" if participants_missing_chat.positive?

      participants_missing_polymorphic = Participant.where(participatable_type: nil).or(Participant.where(participatable_id: nil)).count
      failures << "Participants missing participatable polymorphic fields: #{participants_missing_polymorphic}" if participants_missing_polymorphic.positive?

      duplicate_participants = Participant.where.not(chat_id: nil)
        .group(:chat_id, :participatable_type, :participatable_id)
        .having("COUNT(*) > 1")
        .count
      failures << "Duplicate chat participants found: #{duplicate_participants.size}" if duplicate_participants.any?

      messages_missing_chat = Message.where(chat_id: nil).count
      failures << "Messages missing chat_id: #{messages_missing_chat}" if messages_missing_chat.positive?

      non_system_messages_missing_sender = Message.where.not(role: "system")
        .where(sender_type: nil)
        .or(Message.where.not(role: "system").where(sender_id: nil))
        .count
      failures << "Non-system messages missing sender polymorphic fields: #{non_system_messages_missing_sender}" if non_system_messages_missing_sender.positive?

      Conversation.where.not(agent_id: nil).find_each do |conversation|
        chat_ids = Participant.where(conversation_id: conversation.id).where.not(chat_id: nil).distinct.pluck(:chat_id)
        chat_ids |= Message.where(conversation_id: conversation.id).where.not(chat_id: nil).distinct.pluck(:chat_id)

        if chat_ids.empty?
          failures << "Conversation #{conversation.id} has no derived chat_id on participants/messages"
          next
        end

        if chat_ids.many?
          failures << "Conversation #{conversation.id} maps to multiple chat_ids: #{chat_ids.sort.join(', ')}"
          next
        end

        has_agent_participant = Participant.exists?(
          chat_id: chat_ids.first,
          participatable_type: "Agent",
          participatable_id: conversation.agent_id
        )
        failures << "Conversation #{conversation.id} missing agent participant for agent #{conversation.agent_id}" unless has_agent_participant
      end

      conversation_mapped_chat_ids = Participant.where.not(conversation_id: nil).where.not(chat_id: nil).distinct.pluck(:chat_id)
      missing_conversation_backfills = Conversation.left_joins(:participants).where(participants: { chat_id: nil }).distinct.count
      failures << "Conversations with participant rows missing backfilled chat_id: #{missing_conversation_backfills}" if missing_conversation_backfills.positive?

      if conversation_mapped_chat_ids.size < conversations_count
        failures << "Only #{conversation_mapped_chat_ids.size} chats are linked from backfilled participants for #{conversations_count} conversations"
      end

      if failures.any?
        puts "Backfill validation failed:"
        failures.each { |failure| puts "- #{failure}" }
        raise "chat:migration:validate_backfill failed"
      end

      puts "Backfill validation passed."
    end
  end
end
