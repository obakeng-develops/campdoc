require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "blob reservations enforce the file size limit" do
    user = User.create!(email_address: "sender@example.com")

    error = assert_raises(User::UploadTooLarge) do
      user.reserve_blob!(byte_size: Send::MAX_SEND_SIZE + 1)
    end

    assert_equal "File exceeds Campsend's 2 GB limit.", error.message
    assert_not user.uploaded_blobs.exists?
  end

  test "blob reservations reject negative sizes" do
    user = User.create!(email_address: "sender@example.com")

    error = assert_raises(User::InvalidUploadSize) { user.reserve_blob!(byte_size: -1) }

    assert_equal "File size cannot be negative.", error.message
    assert_not user.uploaded_blobs.exists?
  end

  test "blob reservations use the policy storage service" do
    user = User.create!(email_address: "sender@example.com")
    policy = Class.new(Campsend::Policy) do
      def storage_service_name_for(user:)
        "alternate_test"
      end
    end.new
    original_policy = Campsend.policy
    Campsend.policy = policy

    blob = user.reserve_blob!(
      filename: "hello.txt",
      byte_size: 5,
      checksum: Base64.strict_encode64(Digest::MD5.digest("hello")),
      content_type: "text/plain"
    )

    assert_equal "alternate_test", blob.service_name
    assert_equal user.id, blob.uploader_id
  ensure
    Campsend.policy = original_policy
  end
end
