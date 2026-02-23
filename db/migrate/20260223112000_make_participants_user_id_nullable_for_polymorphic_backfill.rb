class MakeParticipantsUserIdNullableForPolymorphicBackfill < ActiveRecord::Migration[8.1]
  def change
    change_column_null :participants, :user_id, true
  end
end
