require "test_helper"

class SendFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "sender@example.com")
    sign_in_as(@user)
  end

  test "sender creates a file-first delivery" do
    assert_enqueued_with(job: DeliveryEmailJob) do
      assert_difference "Send.count", 1 do
        post sends_path, params: {
          send: {
            recipient_email: "sam@example.com",
            message: "The final draft.",
            files: [ fixture_file_upload("sample.txt", "text/plain") ]
          }
        }
      end
    end

    send_record = Send.last
    assert_redirected_to send_path(send_record)
    follow_redirect!
    assert_response :success
    assert_select ".status-pill--sending", text: "Sending"
    assert_nil send_record.status
    assert_equal "sample.txt", send_record.files.first.filename.to_s
  end

  test "recipient opens and downloads a private delivery" do
    send_record, token = create_send

    get delivery_path(public_id: send_record.public_id)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_select "h1", text: "You have a private delivery."
    assert_not send_record.send_events.opened.exists?

    post delivery_access_path(public_id: send_record.public_id), params: { token: token }
    assert_redirected_to delivery_path(public_id: send_record.public_id)

    post delivery_opened_path(public_id: send_record.public_id)
    assert_response :no_content
    assert send_record.send_events.opened.exists?

    attachment = send_record.files.first
    post download_delivery_file_path(public_id: send_record.public_id, id: attachment.id)
    assert_response :redirect
    assert send_record.send_events.downloaded.exists?
  end

  test "recipient cannot access a delivery with the wrong token" do
    send_record, = create_send
    post delivery_access_path(public_id: send_record.public_id), params: { token: "not-the-token" }
    assert_response :not_found
  end

  test "file routes require an authorized delivery session" do
    send_record, = create_send
    attachment = send_record.files.first

    get delivery_file_path(public_id: send_record.public_id, id: attachment.id)
    assert_response :not_found

    post download_delivery_file_path(public_id: send_record.public_id, id: attachment.id)
    assert_response :not_found
  end

  test "sender can revoke recipient access" do
    send_record, token = create_send
    authorize_delivery(send_record, token)

    post revoke_access_send_path(send_record)
    assert_redirected_to send_path(send_record)

    get delivery_path(public_id: send_record.public_id)
    assert_response :not_found
  end

  test "signed-in sender can prepare a direct upload" do
    get new_send_path
    assert_response :success
    assert_select "aside.site-sidebar"
    assert_select ".selected-state[hidden]"
    assert_select "input[data-direct-upload-url='#{rails_direct_uploads_url}']"

    content = "hello"
    post rails_direct_uploads_path, params: {
      blob: {
        filename: "hello.txt",
        byte_size: content.bytesize,
        checksum: Base64.strict_encode64(Digest::MD5.digest(content)),
        content_type: "text/plain"
      }
    }, as: :json

    assert_response :success
    assert_match %r{/rails/active_storage/disk/}, response.parsed_body.dig("direct_upload", "url")
  end

  test "unsafe image formats are downloaded instead of rendered inline" do
    send_record = @user.sends.new(recipient_email: "sam@example.com")
    token = send_record.issue_access_token
    send_record.files.attach(
      io: StringIO.new('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>'),
      filename: "unsafe.svg",
      content_type: "image/svg+xml"
    )
    send_record.save!
    attachment = send_record.files.first

    get send_file_path(send_record, attachment)
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match(/^attachment;/, response.headers["Content-Disposition"])

    authorize_delivery(send_record, token)
    get delivery_file_path(public_id: send_record.public_id, id: attachment.id)
    assert_response :unsupported_media_type
  end

  private
    def sign_in_as(user)
      login_token, raw_token = LoginToken.issue_for(user)
      post consume_sign_in_path(public_id: login_token.public_id), params: { token: raw_token }
    end

    def authorize_delivery(send_record, raw_token)
      post delivery_access_path(public_id: send_record.public_id), params: { token: raw_token }
    end

    def create_send
      send_record = @user.sends.new(recipient_email: "sam@example.com", message: "For you.")
      token = send_record.issue_access_token
      send_record.files.attach(
        io: file_fixture("sample.txt").open,
        filename: "sample.txt",
        content_type: "text/plain"
      )
      send_record.save!
      send_record.record_event!(:sent)
      [ send_record, token ]
    end
end
