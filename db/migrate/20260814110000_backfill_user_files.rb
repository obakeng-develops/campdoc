class BackfillUserFiles < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO active_storage_attachments (name, record_type, record_id, blob_id, created_at)
      SELECT 'files', 'User', sends.user_id, send_files.blob_id, MIN(send_files.created_at)
      FROM active_storage_attachments AS send_files
      INNER JOIN sends ON sends.id = send_files.record_id
      WHERE send_files.record_type = 'Send'
        AND send_files.name = 'files'
        AND NOT EXISTS (
          SELECT 1
          FROM active_storage_attachments AS user_files
          WHERE user_files.record_type = 'User'
            AND user_files.record_id = sends.user_id
            AND user_files.name = 'files'
            AND user_files.blob_id = send_files.blob_id
        )
      GROUP BY sends.user_id, send_files.blob_id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
