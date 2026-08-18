class CreateCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :collections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.datetime :removed_at
      t.timestamps

      t.index [ :id, :user_id ], unique: true
      t.index [ :user_id, :name ], unique: true, where: "removed_at IS NULL"
      t.check_constraint "length(trim(name)) BETWEEN 1 AND 100", name: "collections_name_length"
    end

    add_index :active_storage_blobs, [ :id, :uploader_id ], unique: true

    create_table :collection_files do |t|
      t.references :collection, null: false
      t.references :user, null: false, foreign_key: true
      t.references :blob, null: false
      t.integer :position, null: false
      t.timestamps

      t.index [ :collection_id, :blob_id ], unique: true
      t.index [ :collection_id, :position ], unique: true
      t.check_constraint "position > 0", name: "collection_files_positive_position"
    end

    add_foreign_key :collection_files, :collections, column: [ :collection_id, :user_id ], primary_key: [ :id, :user_id ]
    add_foreign_key :collection_files, :active_storage_blobs, column: [ :blob_id, :user_id ], primary_key: [ :id, :uploader_id ]

    add_reference :sends, :collection
    add_foreign_key :sends, :collections, column: [ :collection_id, :user_id ], primary_key: [ :id, :user_id ]
    add_column :delivery_revisions, :collection_name, :string
  end
end
