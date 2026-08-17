# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_14_120002) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.integer "uploader_id"
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
    t.index ["uploader_id"], name: "index_active_storage_blobs_on_uploader_id"
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "google_drive_imports", force: :cascade do |t|
    t.integer "blob_id"
    t.datetime "created_at", null: false
    t.string "error"
    t.string "filename", null: false
    t.string "google_file_id", null: false
    t.string "resource_key"
    t.string "status", default: "queued", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["blob_id"], name: "index_google_drive_imports_on_blob_id"
    t.index ["user_id", "status"], name: "index_google_drive_imports_on_user_id_and_status"
    t.index ["user_id"], name: "index_google_drive_imports_on_user_id"
  end

  create_table "login_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "intent"
    t.string "public_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.integer "user_id", null: false
    t.index ["public_id"], name: "index_login_tokens_on_public_id", unique: true
    t.index ["token_digest"], name: "index_login_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_login_tokens_on_user_id"
  end

  create_table "send_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.datetime "occurred_at", null: false
    t.integer "send_id", null: false
    t.datetime "updated_at", null: false
    t.index ["send_id", "event_type"], name: "index_send_events_on_send_id_and_event_type", unique: true
    t.index ["send_id"], name: "index_send_events_on_send_id"
  end

  create_table "sends", force: :cascade do |t|
    t.datetime "access_expires_at"
    t.datetime "access_revoked_at"
    t.string "access_token_digest"
    t.datetime "created_at", null: false
    t.string "email_status", default: "pending", null: false
    t.text "message"
    t.string "public_id", null: false
    t.string "recipient_email", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["access_token_digest"], name: "index_sends_on_access_token_digest", unique: true
    t.index ["public_id"], name: "index_sends_on_public_id", unique: true
    t.index ["recipient_email"], name: "index_sends_on_recipient_email"
    t.index ["user_id"], name: "index_sends_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "plan", default: "free", null: false
    t.integer "send_usage_count", default: 0, null: false
    t.date "send_usage_month"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_blobs", "users", column: "uploader_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "google_drive_imports", "active_storage_blobs", column: "blob_id", on_delete: :nullify
  add_foreign_key "google_drive_imports", "users"
  add_foreign_key "login_tokens", "users"
  add_foreign_key "send_events", "sends"
  add_foreign_key "sends", "users"
end
