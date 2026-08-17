class AddPublicationWakeToSends < ActiveRecord::Migration[8.1]
  def change
    add_column :sends, :publication_enqueued_at, :datetime
  end
end
