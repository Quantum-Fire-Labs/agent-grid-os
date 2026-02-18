module ConversationAccessible
  extend ActiveSupport::Concern

  private
    def require_participant
      unless @conversation.participants.exists?(user_id: Current.user.id)
        head :forbidden
      end
    end
end
