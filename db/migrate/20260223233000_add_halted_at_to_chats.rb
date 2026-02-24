class AddHaltedAtToChats < ActiveRecord::Migration[8.1]
  def change
    add_column :chats, :halted_at, :datetime
  end
end
