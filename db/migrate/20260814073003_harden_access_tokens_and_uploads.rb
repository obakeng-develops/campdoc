class HardenAccessTokensAndUploads < ActiveRecord::Migration[8.1]
  class LoginTokenRecord < ActiveRecord::Base
    self.table_name = "login_tokens"
  end

  class SendRecord < ActiveRecord::Base
    self.table_name = "sends"
  end

  def up
    add_column :login_tokens, :public_id, :string
    add_column :sends, :public_id, :string
    add_column :sends, :access_expires_at, :datetime
    add_column :sends, :access_revoked_at, :datetime
    add_reference :active_storage_blobs, :uploader, foreign_key: { to_table: :users }
    change_column_null :sends, :access_token_digest, true

    LoginTokenRecord.reset_column_information
    LoginTokenRecord.find_each { |record| record.update_columns(public_id: SecureRandom.urlsafe_base64(18)) }
    SendRecord.reset_column_information
    SendRecord.find_each do |record|
      record.update_columns(
        public_id: SecureRandom.urlsafe_base64(18),
        access_expires_at: 30.days.from_now
      )
    end

    change_column_null :login_tokens, :public_id, false
    change_column_null :sends, :public_id, false
    add_index :login_tokens, :public_id, unique: true
    add_index :sends, :public_id, unique: true
  end

  def down
    remove_index :sends, :public_id
    remove_index :login_tokens, :public_id
    remove_reference :active_storage_blobs, :uploader
    remove_column :sends, :access_revoked_at
    remove_column :sends, :access_expires_at
    remove_column :sends, :public_id
    remove_column :login_tokens, :public_id
    change_column_null :sends, :access_token_digest, false
  end
end
