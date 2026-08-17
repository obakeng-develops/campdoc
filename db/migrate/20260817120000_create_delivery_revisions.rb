class CreateDeliveryRevisions < ActiveRecord::Migration[8.1]
  def up
    create_table :delivery_revisions do |t|
      t.references :send, null: false, foreign_key: true
      t.integer :number, null: false
      t.timestamps
    end
    add_index :delivery_revisions, [ :send_id, :number ], unique: true

    execute <<~SQL
      INSERT INTO delivery_revisions (send_id, number, created_at, updated_at)
      SELECT id, 1, created_at, updated_at FROM sends
    SQL

    execute <<~SQL
      UPDATE active_storage_attachments
      SET record_type = 'DeliveryRevision',
          record_id = (
            SELECT delivery_revisions.id
            FROM delivery_revisions
            WHERE delivery_revisions.send_id = active_storage_attachments.record_id
              AND delivery_revisions.number = 1
          )
      WHERE record_type = 'Send' AND name = 'files'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE active_storage_attachments
      SET record_type = 'Send',
          record_id = (
            SELECT delivery_revisions.send_id
            FROM delivery_revisions
            WHERE delivery_revisions.id = active_storage_attachments.record_id
          )
      WHERE record_type = 'DeliveryRevision' AND name = 'files'
    SQL

    drop_table :delivery_revisions
  end
end
