class AddSchedulingToSends < ActiveRecord::Migration[8.1]
  def up
    add_column :sends, :scheduled_at, :datetime
    add_column :sends, :published_at, :datetime
    add_column :sends, :canceled_at, :datetime
    add_index :sends, :published_at
    add_index :sends, [ :canceled_at, :published_at, :scheduled_at ]
    add_check_constraint :sends, "published_at IS NULL OR canceled_at IS NULL", name: "sends_publication_state"

    execute <<~SQL
      UPDATE sends
      SET published_at = (
        SELECT send_events.occurred_at
        FROM send_events
        WHERE send_events.send_id = sends.id
          AND send_events.event_type = 'sent'
      )
      WHERE EXISTS (
        SELECT 1
        FROM send_events
        WHERE send_events.send_id = sends.id
          AND send_events.event_type = 'sent'
      )
    SQL
  end

  def down
    remove_check_constraint :sends, name: "sends_publication_state"
    remove_index :sends, [ :canceled_at, :published_at, :scheduled_at ]
    remove_index :sends, :published_at
    remove_columns :sends, :scheduled_at, :published_at, :canceled_at
  end
end
