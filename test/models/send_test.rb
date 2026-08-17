require "test_helper"

class SendTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "sender@example.com")
  end

  test "requires a recipient and file" do
    send_record = @user.sends.new
    send_record.issue_access_token

    assert_not send_record.valid?
    assert_includes send_record.errors[:recipient_email], "can't be blank"
    assert_includes send_record.errors[:base], "Choose at least one file."
  end

  test "status follows the furthest recipient event" do
    send_record = create_send
    send_record.record_event!(:sent)
    send_record.record_event!(:opened)
    send_record.record_event!(:downloaded)

    assert_equal "downloaded", send_record.status
    assert_equal 3, send_record.send_events.count
  end

  test "delivery access expires and can be revoked" do
    send_record = create_send

    assert send_record.access_active?
    send_record.update!(access_expires_at: 1.minute.ago)
    assert_not send_record.access_active?

    send_record.issue_access_token!
    send_record.revoke_access!
    assert_not send_record.access_active?
  end

  test "display status prioritizes email and access state" do
    send_record = create_send
    assert_equal "sending", send_record.display_status

    send_record.update!(email_status: "failed")
    assert_equal "failed", send_record.display_status

    send_record.record_event!(:sent)
    send_record.update!(access_expires_at: 1.minute.ago)
    assert_equal "expired", send_record.display_status

    send_record.revoke_access!
    assert_equal "revoked", send_record.display_status
  end

  test "rejects a direct-upload blob owned by another sender" do
    other_user = User.create!(email_address: "other@example.com")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("private"),
      filename: "private.txt",
      content_type: "text/plain"
    )
    blob.update!(uploader_id: other_user.id)

    send_record = @user.sends.new(recipient_email: "sam@example.com", files: [ blob ])
    send_record.issue_access_token

    assert_not send_record.valid?
    assert_includes send_record.errors[:base], "You can only send files you uploaded."
  end

  test "rejects an ownerless blob" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("ownerless"),
      filename: "ownerless.txt",
      content_type: "text/plain"
    )
    send_record = @user.sends.new(recipient_email: "sam@example.com", files: [ blob ])

    assert_not send_record.valid?
    assert_includes send_record.errors[:base], "You can only send files you uploaded."
  end

  test "creates an immutable first revision" do
    send_record = create_send

    assert_equal [ 1 ], send_record.delivery_revisions.pluck(:number)
    assert_equal send_record.files.first.blob_id, send_record.delivery_revisions.first.files.first.blob_id
    assert_raises(ActiveRecord::ReadOnlyRecord) { send_record.files = [ create_uploaded_blob(@user) ] }
  end

  test "replacing a file preserves the previous revision" do
    send_record = create_send
    original_blob = send_record.files.first.blob
    replacement = create_uploaded_blob(@user, content: "updated", filename: "updated.txt")

    revision = send_record.replace_file!(send_record.files.first.id, replacement)

    assert_equal 2, revision.number
    assert_equal replacement.id, send_record.reload.files.first.blob_id
    assert_equal original_blob.id, send_record.delivery_revisions.find_by!(number: 1).files.first.blob_id
  end

  test "revision numbers are unique within a delivery" do
    send_record = create_send
    duplicate = send_record.delivery_revisions.build(number: 1, files: [ create_uploaded_blob(@user) ])

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:number], "has already been taken"
  end

  test "rejects a replacement owned by another sender" do
    send_record = create_send
    other_user = User.create!(email_address: "other@example.com")
    replacement = create_uploaded_blob(other_user)

    assert_no_difference "DeliveryRevision.count" do
      assert_raises(ActiveRecord::RecordInvalid) do
        send_record.replace_file!(send_record.files.first.id, replacement)
      end
    end
  end

  private
    def create_send
      send_record = @user.sends.new(recipient_email: "sam@example.com")
      send_record.issue_access_token
      send_record.files.attach(create_uploaded_blob(@user))
      send_record.save!
      send_record
    end
end
