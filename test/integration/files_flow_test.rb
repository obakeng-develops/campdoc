require "test_helper"

class FilesFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "sender@example.com")
    sign_in_as(@user)
  end

  test "user uploads and downloads an owned file" do
    blob = create_blob(@user, "draft")

    post files_path, params: { files: [ blob.signed_id ] }
    assert_redirected_to files_path
    assert_equal [ blob.id ], @user.files.blobs.ids

    get download_file_path(@user.files.attachments.first)
    assert_response :redirect
  end

  test "sending an uploaded file keeps it in My Files" do
    blob = create_blob(@user, "contract")

    post sends_path, params: {
      send: { recipient_email: "sam@example.com", files: [ blob.signed_id ] }
    }

    assert_response :redirect
    assert_equal [ blob.id ], @user.files.blobs.ids
  end

  test "existing files can be selected for another Send" do
    blob = create_blob(@user, "invoice")
    @user.retain_files([ blob ])
    file = @user.files.attachments.first

    get new_send_path(file_id: file.id)

    assert_response :success
    assert_select "#library_file_#{file.id}[checked]"
  end

  test "removing a library file preserves existing deliveries" do
    blob = create_blob(@user, "photos")
    send_record = @user.sends.new(recipient_email: "sam@example.com")
    send_record.issue_access_token
    send_record.files.attach(blob)
    send_record.save!
    @user.retain_files([ blob ])

    delete file_path(@user.files.attachments.first)

    assert_redirected_to files_path
    assert_not @user.reload.files.attached?
    assert ActiveStorage::Blob.exists?(blob.id)
    assert_equal blob.id, send_record.files.first.blob_id
  end

  test "user cannot retain another sender's blob" do
    other_user = User.create!(email_address: "other@example.com")
    blob = create_blob(other_user, "private")

    post files_path, params: { files: [ blob.signed_id ] }

    assert_response :forbidden
    assert_not @user.files.attached?
  end

  private
    def create_blob(user, content)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(content),
        filename: "#{content}.txt",
        content_type: "text/plain"
      )
      blob.update!(uploader_id: user.id)
      blob
    end

    def sign_in_as(user)
      login_token, raw_token = LoginToken.issue_for(user)
      post consume_sign_in_path(public_id: login_token.public_id), params: { token: raw_token }
    end
end
