require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "sender signs in with a single-use link" do
    user = User.create!(email_address: "sender@example.com")
    login_token, raw_token = LoginToken.issue_for(user)

    get sign_in_path(public_id: login_token.public_id)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert login_token.reload.usable?

    post consume_sign_in_path(public_id: login_token.public_id), params: { token: raw_token }
    assert_redirected_to files_path
    follow_redirect!
    assert_response :success

    delete session_path
    assert_redirected_to new_session_path
    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Your files, delivered personally."

    post consume_sign_in_path(public_id: login_token.public_id), params: { token: raw_token }
    assert_redirected_to new_session_path
  end

  test "landing page sends signed-in users to their home" do
    with_managed_hosting do
      get root_path
      assert_response :success
      assert_select ".handoff-scene"
      assert_select ".mini-composer"
      assert_select ".mini-delivery"
      assert_select "[data-controller='handoff']"
      assert_select ".landing-ledger[data-controller='handoff']"
      assert_select ".manifesto-signature", text: /Obakeng Mosadi/
      assert_select "a[href='mailto:mosadiobakeng7@gmail.com']"

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
      assert_select ".plan-label", text: "Coming soon", count: 2
      assert_select ".plan-label--available", text: "Available now"
      assert_select ".plan-features", text: /200 GB storage per member/

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
  end

  test "direct upload grants require a signed-in sender" do
    post rails_direct_uploads_path, params: { blob: blob_params }, as: :json

    assert_response :unauthorized
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
    assert_not ActiveStorage::Blob.exists?
  end

  private
    def with_managed_hosting
      previous_value = Rails.configuration.x.managed_hosting
      Rails.configuration.x.managed_hosting = true
      yield
    ensure
      Rails.configuration.x.managed_hosting = previous_value
    end

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
end
