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
    assert_includes send_record.errors[:files], "Choose at least one file"
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
    assert_includes send_record.errors[:files], "Include a file uploaded by another account"
  end

  private
    def create_send
      send_record = @user.sends.new(recipient_email: "sam@example.com")
      send_record.issue_access_token
      send_record.files.attach(io: StringIO.new("hello"), filename: "hello.txt", content_type: "text/plain")
      send_record.save!
      send_record
    end
end
