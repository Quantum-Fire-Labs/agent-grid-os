class AddArchivedAtToChats < ActiveRecord::Migration[8.1]
  def change
    add_column :chats, :archived_at, :datetime
  end
end
