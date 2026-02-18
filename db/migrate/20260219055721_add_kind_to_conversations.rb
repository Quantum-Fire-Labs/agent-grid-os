class AddKindToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :kind, :string, null: false, default: "direct"
  end
end
