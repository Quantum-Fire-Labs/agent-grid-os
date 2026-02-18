class AddCompactedAtToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :compacted_at, :datetime
  end
end
