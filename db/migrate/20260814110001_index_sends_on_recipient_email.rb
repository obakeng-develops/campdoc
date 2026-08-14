class IndexSendsOnRecipientEmail < ActiveRecord::Migration[8.1]
  def change
    add_index :sends, :recipient_email
  end
end
