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
    assert_redirected_to new_session_path
    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Sign in or start free."

    post consume_sign_in_path(public_id: login_token.public_id), params: { token: raw_token }
    assert_redirected_to new_session_path
  end

  test "landing page sends signed-in users to their home" do
    with_managed_hosting do
      get root_path
      assert_response :success
      assert_select "img.wordmark-logo[alt='Campdoc']"
      assert_select ".handoff-scene"
      assert_select "img.mini-app__mark[alt='']"
      assert_select ".mini-composer"
      assert_select ".mini-delivery"
      assert_select "[data-controller='handoff']"
      assert_select ".landing-ledger[data-controller='handoff']"
      assert_select ".manifesto-signature", text: /Obakeng Mosadi/
      assert_select "a[href='mailto:mosadiobakeng7@gmail.com']"
      assert_select "a.github-link[href='https://github.com/obakeng-develops/campdoc'][aria-label='Campdoc on GitHub'] svg", count: 1
      assert_select "a[href='#{new_session_path(intent: "send")}']", text: "Send files"

      user = User.create!(email_address: "sender@example.com")
      sign_in_as(user)
      get root_path
      assert_redirected_to files_path
    end
  end

  test "pricing is public and stays in the marketing frame" do
    with_managed_hosting do
      get pricing_path

      assert_response :success
      assert_select ".pricing-card", count: 3
      assert_select ".plan-price strong", text: "$9"
      assert_select ".plan-price strong", text: "$49"
      assert_select ".plan-label", text: "Planned", count: 2
      assert_select ".plan-label--available", text: "Available now"
      assert_select ".plan-features", text: /250 GB storage/
      assert_select ".plan-features", text: /3 TB shared storage/
      assert_select ".plan-features", text: /Unlimited members/
      assert_select ".pricing-note", text: /provide the server, storage, and email service/
      assert_select "a[href='https://github.com/obakeng-develops/campdoc']", text: "Self-host Campdoc"

      user = User.create!(email_address: "sender@example.com")
      sign_in_as(user)
      get pricing_path

      assert_response :success
      assert_select ".landing-header"
      assert_select ".site-sidebar", count: 0
    end
  end

  test "self-hosted mode starts at sign-in and hides pricing" do
    get root_path
    assert_redirected_to new_session_path

    get pricing_path
    assert_response :not_found
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
    assert_equal "File exceeds Campdoc's 2 GB limit.", response.parsed_body.fetch("error")
    assert_not ActiveStorage::Blob.exists?
  end

  test "managed accounts see plan usage" do
    user = User.create!(email_address: "sender@example.com")
    create_uploaded_blob(user)

    with_managed_hosting do
      sign_in_as(user)
      get files_path

      assert_response :success
      assert_select ".plan-usage", count: 2
      assert_select ".plan-usage", text: /5 Bytes of 2 GB/
      assert_select ".plan-usage", text: /0 of 5 deliveries sent this month/

      user.update!(plan: "pro")
      get files_path
      assert_select ".plan-usage", text: /Pro/, count: 2
      assert_select ".plan-usage", text: /250 GB/, count: 2
      assert_select ".plan-usage", text: /deliveries sent this month/, count: 0
    end
  end

  test "managed storage is reserved before direct upload" do
    user = User.create!(email_address: "sender@example.com")
    reserve_storage(user, user.storage_limit)

    with_managed_hosting do
      sign_in_as(user)

      assert_no_difference "ActiveStorage::Blob.count" do
        post rails_direct_uploads_path, params: { blob: blob_params }, as: :json
      end
      assert_response :unprocessable_content
      assert_match "Storage limit reached", response.parsed_body.fetch("error")
    end
  end

  test "managed Pro accounts have 250 GB of storage" do
    user = User.create!(email_address: "sender@example.com", plan: "pro")
    assert_equal 250.gigabytes, user.storage_limit
    reserve_storage(user, user.storage_limit)

    with_managed_hosting do
      sign_in_as(user)
      post rails_direct_uploads_path, params: { blob: blob_params }, as: :json

      assert_response :unprocessable_content
    end
  end

  test "self-hosted accounts do not have aggregate storage quotas" do
    user = User.create!(email_address: "sender@example.com")
    reserve_storage(user, user.storage_limit)
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
