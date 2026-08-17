class AddJourneyState < ActiveRecord::Migration[8.1]
  def up
    add_column :login_tokens, :intent, :string
    add_column :sends, :email_status, :string, null: false, default: "pending"

    execute <<~SQL
      UPDATE sends
      SET email_status = 'sent'
      WHERE EXISTS (
        SELECT 1 FROM send_events
        WHERE send_events.send_id = sends.id
          AND send_events.event_type = 'sent'
      )
    SQL
  end

  def down
    remove_column :sends, :email_status
    remove_column :login_tokens, :intent
  end
end
