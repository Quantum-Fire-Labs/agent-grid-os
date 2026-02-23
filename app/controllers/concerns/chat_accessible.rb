module ChatAccessible
  extend ActiveSupport::Concern

  private
    def require_chat_participant
      unless @chat.users.exists?(id: Current.user.id)
        head :forbidden
      end
    end
end
