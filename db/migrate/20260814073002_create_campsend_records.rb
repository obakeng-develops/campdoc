class CreateCampsendRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.timestamps
    end
    add_index :users, :email_address, unique: true

    create_table :login_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end
    add_index :login_tokens, :token_digest, unique: true

    create_table :sends do |t|
      t.references :user, null: false, foreign_key: true
      t.string :recipient_email, null: false
      t.text :message
      t.string :access_token_digest, null: false
      t.timestamps
    end
    add_index :sends, :access_token_digest, unique: true

    create_table :send_events do |t|
      t.references :send, null: false, foreign_key: true
      t.string :event_type, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :send_events, [ :send_id, :event_type ], unique: true
  end
end
