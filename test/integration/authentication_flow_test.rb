require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "sender signs in with a single-use link" do
    user = User.create!(email_address: "sender@example.com")
    login_token, raw_token = LoginToken.issue_for(user)

    get sign_in_path(public_id: login_token.public_id)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert login_token.reload.usable?
    assert_select "[data-secret-fragment-target='message'][hidden]", text: /link is incomplete/

    post consume_sign_in_path(public_id: login_token.public_id), params: { token: raw_token }
    assert_redirected_to files_path
    follow_redirect!
    assert_response :success

    delete session_path
    assert_redirected_to root_path
    follow_redirect!
    assert_redirected_to new_session_path
    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Sign in or start free."
    assert_select ".auth-feedback--notice", text: "You’re signed out."

    post consume_sign_in_path(public_id: login_token.public_id), params: { token: raw_token }
    assert_redirected_to new_session_path
  end

  test "self-hosted mode starts at sign-in and has no pricing page" do
    get root_path
    assert_redirected_to new_session_path

    get "/pricing"
    assert_response :not_found
  end

  test "protected pages redirect without redundant sign-in feedback" do
    get files_path

    assert_redirected_to new_session_path
    follow_redirect!
    assert_select ".flash-stack", count: 0
    assert_select ".auth-feedback", count: 0
  end

  test "sign-in errors appear inside the auth card" do
    post session_path, params: { email_address: "not-an-email" }

    assert_response :unprocessable_content
    assert_select ".auth-card .auth-feedback--alert[role='alert']", text: "Enter a valid email address."
    assert_select ".flash-stack", count: 0
  end

  test "expired sign-in links explain the error inside the auth card" do
    user = User.create!(email_address: "sender@example.com")
    login_token, = LoginToken.issue_for(user)
    login_token.update!(expires_at: 1.minute.ago)

    get sign_in_path(public_id: login_token.public_id)
    assert_redirected_to new_session_path
    follow_redirect!

    assert_select ".auth-card .auth-feedback--alert", text: "That sign-in link has expired. Ask for a new one."
  end

  test "requesting a link creates a sender and queues email" do
    assert_enqueued_with(job: AuthenticationEmailJob) do
      post session_path, params: { email_address: "New@Example.com" }
    end

    assert_redirected_to new_session_path
    assert_equal "new@example.com", User.last.email_address
    follow_redirect!
    assert_select "h1", text: "Check your inbox."
    assert_select ".auth-copy", text: /new@example.com/
    assert_select "form", count: 0

    get new_session_path
    assert_select "h1", text: "Check your inbox."
    get new_session_path(change_email: 1)
    assert_select "h1", text: "Sign in or start free."
  end

  test "send intent survives the sign-in link" do
    user = User.create!(email_address: "sender@example.com")
    login_token, raw_token = LoginToken.issue_for(user, intent: "send")

    post consume_sign_in_path(public_id: login_token.public_id), params: { token: raw_token }

    assert_redirected_to new_send_path
  end

  test "direct upload grants require a signed-in sender" do
    post rails_direct_uploads_path, params: { blob: blob_params }, as: :json

    assert_response :unauthorized
    assert_equal "Sign in to upload files.", response.parsed_body.fetch("error")
    assert_not ActiveStorage::Blob.exists?
  end

  test "direct upload grants reject an expired sender session" do
    user = User.create!(email_address: "sender@example.com")
    sign_in_as(user)

    travel Authentication::SESSION_LIFETIME + 1.minute do
      post rails_direct_uploads_path, params: { blob: blob_params }, as: :json
    end

    assert_response :unauthorized
    assert_not ActiveStorage::Blob.exists?
  end

  test "oversized direct uploads are rejected" do
    user = User.create!(email_address: "sender@example.com")
    sign_in_as(user)

    post rails_direct_uploads_path, params: {
      blob: blob_params.merge(byte_size: Send::MAX_SEND_SIZE + 1)
    }, as: :json

    assert_response :content_too_large
    assert_equal "File exceeds Campsend's 2 GB limit.", response.parsed_body.fetch("error")
    assert_not ActiveStorage::Blob.exists?
  end

  test "self-hosted accounts do not have aggregate storage quotas" do
    user = User.create!(email_address: "sender@example.com")
    reserve_storage(user, 2.gigabytes)
    sign_in_as(user)

    assert_difference "ActiveStorage::Blob.count", 1 do
      post rails_direct_uploads_path, params: { blob: blob_params }, as: :json
    end
    assert_response :success
  end

  private
    def sign_in_as(user)
      login_token, raw_token = LoginToken.issue_for(user)
      post consume_sign_in_path(public_id: login_token.public_id), params: { token: raw_token }
    end

    def blob_params
      content = "hello"
      {
        filename: "hello.txt",
        byte_size: content.bytesize,
        checksum: Base64.strict_encode64(Digest::MD5.digest(content)),
        content_type: "text/plain"
      }
    end

    def reserve_storage(user, byte_size)
      ActiveStorage::Blob.create_before_direct_upload!(
        filename: "reserved.bin",
        byte_size: byte_size,
        checksum: Base64.strict_encode64(Digest::MD5.digest("reserved")),
        content_type: "application/octet-stream"
      ).update!(uploader_id: user.id)
    end
end
