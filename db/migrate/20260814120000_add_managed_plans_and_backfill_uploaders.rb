class AddManagedPlansAndBackfillUploaders < ActiveRecord::Migration[8.1]
  class Blob < ActiveRecord::Base
    self.table_name = "active_storage_blobs"
  end

  class UserRecord < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    add_column :users, :plan, :string, null: false, default: "free"
    add_column :users, :send_usage_month, :date
    add_column :users, :send_usage_count, :integer, null: false, default: 0

    month = Time.current.beginning_of_month
    UserRecord.reset_column_information
    UserRecord.find_each do |user|
      count = select_value(<<~SQL).to_i
        SELECT COUNT(*) FROM sends
        WHERE user_id = #{connection.quote(user.id)}
          AND created_at >= #{connection.quote(month)}
          AND created_at < #{connection.quote(month.next_month)}
      SQL
      user.update_columns(send_usage_month: month.to_date, send_usage_count: count)
    end

    Blob.where(uploader_id: nil).find_each do |blob|
      user_ids = select_values(<<~SQL).map(&:to_i).uniq
        SELECT record_id
        FROM active_storage_attachments
        WHERE blob_id = #{connection.quote(blob.id)}
          AND record_type = 'User'
          AND name = 'files'
        UNION
        SELECT sends.user_id
        FROM active_storage_attachments
        INNER JOIN sends ON sends.id = active_storage_attachments.record_id
        WHERE active_storage_attachments.blob_id = #{connection.quote(blob.id)}
          AND active_storage_attachments.record_type = 'Send'
          AND active_storage_attachments.name = 'files'
      SQL

      raise "Blob #{blob.id} belongs to multiple users" if user_ids.many?

      blob.update_columns(uploader_id: user_ids.first) if user_ids.one?
    end
  end

  def down
    remove_column :users, :send_usage_count
    remove_column :users, :send_usage_month
    remove_column :users, :plan
  end
end
