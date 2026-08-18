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
end
