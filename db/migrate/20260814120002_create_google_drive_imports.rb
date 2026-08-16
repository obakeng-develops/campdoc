class CreateGoogleDriveImports < ActiveRecord::Migration[8.1]
  def change
    create_table :google_drive_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :blob, foreign_key: { to_table: :active_storage_blobs, on_delete: :nullify }
      t.string :google_file_id, null: false
      t.string :resource_key
      t.string :filename, null: false
      t.string :status, null: false, default: "queued"
      t.string :error
      t.timestamps
    end

    add_index :google_drive_imports, [ :user_id, :status ]
  end
end
