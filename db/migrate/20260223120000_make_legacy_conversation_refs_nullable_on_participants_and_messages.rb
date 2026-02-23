class MakeLegacyConversationRefsNullableOnParticipantsAndMessages < ActiveRecord::Migration[8.1]
  def change
    change_column_null :participants, :conversation_id, true
  end
end
