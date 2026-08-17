require "test_helper"

class SendFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "sender@example.com")
    sign_in_as(@user)
  end

  test "sender creates a file-first delivery" do
    blob = create_uploaded_blob(@user, content: "sample", filename: "sample.txt")

    assert_enqueued_with(job: DeliveryEmailJob) do
      assert_difference "Send.count", 1 do
        post sends_path, params: {
          send: {
            recipient_email: "sam@example.com",
            message: "The final draft.",
            files: [ blob.signed_id ]
          }
        }
      end
    end

    send_record = Send.last
    assert_redirected_to send_path(send_record)
    follow_redirect!
    assert_response :success
    assert_select ".status-pill--sending", text: "Sending"
    assert_select "meta[http-equiv='refresh'][content='3']", count: 1
    assert_select "form.file-replacement[action='#{send_revisions_path(send_record)}']" do
      assert_select "input[type='file'][required]"
      assert_select "input[type='submit'][value='Replace file']"
    end
    assert_nil send_record.status
    assert_equal "sample.txt", send_record.files.first.filename.to_s
    assert_equal [ 1 ], send_record.delivery_revisions.pluck(:number)
  end

  test "sender schedules a delivery in UTC" do
    blob = create_uploaded_blob(@user, filename: "scheduled.txt")
    scheduled_at = 2.days.from_now.change(usec: 0)

    assert_enqueued_with(job: DeliveryEmailJob, at: scheduled_at) do
      post sends_path, params: {
        send: {
          recipient_email: "later@example.com",
          files: [ blob.signed_id ],
          scheduled_at: scheduled_at.iso8601
        }
      }
    end

    send_record = Send.last
    assert_equal scheduled_at, send_record.scheduled_at
    assert_nil send_record.published_at
    assert_redirected_to send_path(send_record)
    follow_redirect!
    assert_select ".status-pill--scheduled", text: "Scheduled"
    assert_select "meta[http-equiv='refresh']", count: 0
    assert_select "time[data-controller='local-time'][datetime='#{scheduled_at.iso8601}']"
    assert_select "a[href='#{edit_send_path(send_record)}']", text: "Edit schedule"
    assert_select "form[action='#{cancel_send_path(send_record)}']", text: "Cancel delivery"
  end

  test "sender edits and clears a schedule before publication" do
    send_record = create_scheduled_send
    changed_at = 3.days.from_now.change(usec: 0)

    assert_enqueued_with(job: DeliveryEmailJob, at: changed_at) do
      patch send_path(send_record), params: {
        send: { recipient_email: "changed@example.com", message: "Updated", scheduled_at: changed_at.iso8601 }
      }
    end

    assert_redirected_to send_path(send_record)
    assert_equal "changed@example.com", send_record.reload.recipient_email
    assert_equal "Updated", send_record.message
    assert_equal changed_at, send_record.scheduled_at

    assert_enqueued_with(job: DeliveryEmailJob) do
      patch send_path(send_record), params: {
        send: { recipient_email: send_record.recipient_email, message: send_record.message, scheduled_at: "" }
      }
    end
    assert_nil send_record.reload.scheduled_at
  end

  test "unpublished delivery links reveal no delivery details" do
    send_record = create_scheduled_send
    delete session_path
    follow_redirect!

    get delivery_path(public_id: send_record.public_id)

    assert_response :not_found
    assert_select "h1", text: "This delivery isn’t available yet."
    assert_not_includes response.body, @user.email_address
    assert_not_includes response.body, send_record.recipient_email
    assert_not_includes response.body, send_record.files.first.filename.to_s

    post delivery_access_path(public_id: send_record.public_id), params: { token: "not-issued" }
    assert_response :not_found
    get delivery_file_path(public_id: send_record.public_id, id: send_record.files.first.id)
    assert_response :not_found
  end

  test "canceling a scheduled delivery keeps its quota reservation" do
    blob = create_uploaded_blob(@user)

    with_managed_hosting do
      post sends_path, params: {
        send: { recipient_email: "later@example.com", files: [ blob.signed_id ], scheduled_at: 2.days.from_now.iso8601 }
      }
      send_record = Send.last

      post cancel_send_path(send_record)

      assert_redirected_to send_path(send_record)
      assert send_record.reload.canceled?
      assert_equal 1, @user.reload.sends_this_month
      assert_no_difference -> { ActionMailer::Base.deliveries.size } do
        DeliveryEmailJob.perform_now(send_record)
      end
    end
  end

  test "published deliveries cannot be edited or canceled" do
    send_record, = create_send

    patch send_path(send_record), params: {
      send: { recipient_email: "changed@example.com", message: "Changed", scheduled_at: 2.days.from_now.iso8601 }
    }
    assert_redirected_to send_path(send_record)
    assert_equal "sam@example.com", send_record.reload.recipient_email

    post cancel_send_path(send_record)
    assert_redirected_to send_path(send_record)
    assert_not send_record.reload.canceled?
  end

  test "sender replaces a file while recipients see only the latest revision" do
    send_record, token = create_send
    original_attachment = send_record.files.first
    replacement = create_uploaded_blob(@user, content: "updated", filename: "updated.txt")

    assert_difference "DeliveryRevision.count", 1 do
      post send_revisions_path(send_record), params: {
        revision: { attachment_id: original_attachment.id, file: replacement.signed_id }
      }
    end

    assert_redirected_to send_path(send_record)
    assert_equal %w[updated.txt], send_record.reload.files.map { |file| file.filename.to_s }
    assert @user.reload.files.blobs.exists?(replacement.id)

    get send_path(send_record)
    assert_select "#revision-history-title", text: "Previous versions"
    assert_select ".revision-history", text: /Version 1/
    assert_select ".revision-history", text: /sample.txt/

    get send_file_path(send_record, original_attachment)
    assert_response :redirect

    authorize_delivery(send_record, token)
    get delivery_path(public_id: send_record.public_id)
    assert_select ".delivery-file", text: /updated.txt/
    assert_select ".delivery-file", text: /sample.txt/, count: 0

    get delivery_file_path(public_id: send_record.public_id, id: original_attachment.id)
    assert_response :not_found
  end

  test "recipient opens and downloads a delivery" do
    send_record, token = create_send

    get delivery_path(public_id: send_record.public_id)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_select "h1", text: "sender@example.com sent you a delivery."
    assert_select "[data-secret-fragment-target='message'][hidden]", text: /link is incomplete/
    assert_not send_record.send_events.opened.exists?

    post delivery_access_path(public_id: send_record.public_id), params: { token: token }
    assert_redirected_to delivery_path(public_id: send_record.public_id)

    get delivery_path(public_id: send_record.public_id)
    assert_select "form[data-turbo='false'][action='#{download_delivery_file_path(public_id: send_record.public_id, id: send_record.files.first.id)}']"

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
    assert_select "h1", text: "This delivery is no longer available."
  end

  test "signed-in sender can prepare a direct upload" do
    get new_send_path
    assert_response :success
    assert_select "aside.site-sidebar"
    assert_select ".selected-state[hidden]"
    assert_select "input[data-direct-upload-url='#{rails_direct_uploads_url}']"
    assert_select "form[data-controller~='upload-progress']"
    assert_select "form[data-controller~='schedule']"
    assert_select "input[type='datetime-local']"
    assert_select "input[type='hidden'][name='send[scheduled_at]']"
    assert_select "input[type='hidden'][name='send[schedule_synced]']"
    assert_select "[data-upload-progress-target='error'][hidden]"

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
    blob = ActiveStorage::Blob.find_signed!(response.parsed_body.fetch("signed_id"))
    assert_equal @user.id, blob.uploader_id
    assert_match %r{\Ausers/#{@user.id}/blobs/[a-z0-9]{28}\z}, blob.key
  end

  test "server-side multipart uploads are rejected" do
    assert_no_difference "Send.count" do
      post sends_path, params: {
        send: {
          recipient_email: "sam@example.com",
          files: [ fixture_file_upload("sample.txt", "text/plain") ]
        }
      }
    end

    assert_response :bad_request
  end

  test "a selected local schedule fails closed when browser conversion does not run" do
    blob = create_uploaded_blob(@user)

    assert_no_enqueued_jobs only: DeliveryEmailJob do
      assert_no_difference "Send.count" do
        post sends_path, params: {
          send: {
            recipient_email: "later@example.com",
            files: [ blob.signed_id ],
            scheduled_local: "2026-08-20T10:00",
            scheduled_at: "",
            schedule_synced: ""
          }
        }
      end
    end

    assert_response :unprocessable_content
    assert_select ".form-errors", text: /could not be converted to UTC/
  end

  test "managed Free accounts are limited to five deliveries each month" do
    blob = create_uploaded_blob(@user)

    with_managed_hosting do
      5.times do
        post sends_path, params: { send: { recipient_email: "sam@example.com", files: [ blob.signed_id ] } }
        assert_response :redirect
      end
      delete send_path(@user.sends.first)

      assert_no_difference "Send.count" do
        post sends_path, params: { send: { recipient_email: "sam@example.com", files: [ blob.signed_id ] } }
      end
      assert_response :unprocessable_content
      assert_select ".form-errors", text: /includes 5 deliveries each month/

      travel 1.month do
        sign_in_as(@user)
        assert_difference "Send.count", 1 do
          post sends_path, params: { send: { recipient_email: "sam@example.com", files: [ blob.signed_id ] } }
        end
        assert_response :redirect
      end
    end
  end

  test "failed delivery email has a clear retry state" do
    send_record, = create_send
    send_record.update!(email_status: "failed")

    get send_path(send_record)

    assert_response :success
    assert_select ".status-pill--failed", text: "Failed"
    assert_select "form[action='#{rotate_access_send_path(send_record)}'] button", text: "Try emailing again"
    assert_select "meta[http-equiv='refresh']", count: 0
  end

  test "failed first publication retries publication while published links rotate" do
    unpublished = create_scheduled_send
    unpublished.update!(email_status: "failed")

    assert_enqueued_with(job: DeliveryEmailJob) do
      post rotate_access_send_path(unpublished)
    end

    published, = create_send
    published.update!(email_status: "failed")
    assert_enqueued_with(job: DeliveryAccessEmailJob) do
      post rotate_access_send_path(published)
    end
  end

  test "unpublished deliveries cannot be deleted while delayed jobs may exist" do
    send_record = create_scheduled_send

    assert_no_difference "Send.count" do
      delete send_path(send_record)
    end

    assert_redirected_to send_path(send_record)
  end

  test "managed Pro accounts have unlimited deliveries" do
    @user.update!(plan: "pro")
    blob = create_uploaded_blob(@user)

    with_managed_hosting do
      assert_difference "Send.count", 6 do
        6.times do
          post sends_path, params: { send: { recipient_email: "sam@example.com", files: [ blob.signed_id ] } }
          assert_response :redirect
        end
      end
    end
  end

  test "deleting a delivery removes access but keeps library files" do
    send_record, = create_send
    @user.retain_files(send_record.files.blobs)
    blob = send_record.files.first.blob

    assert_difference "Send.count", -1 do
      delete send_path(send_record)
    end

    assert_redirected_to sends_path
    assert @user.reload.files.attached?
    get delivery_path(public_id: send_record.public_id)
    assert_response :not_found

    perform_enqueued_jobs { delete file_path(@user.files.attachments.first) }
    assert_not ActiveStorage::Blob.exists?(blob.id)
  end

  test "unsafe image formats are downloaded instead of rendered inline" do
    send_record = @user.sends.new(recipient_email: "sam@example.com")
    token = send_record.issue_access_token
    send_record.files.attach(create_uploaded_blob(
      @user,
      content: '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>',
      filename: "unsafe.svg",
      content_type: "image/svg+xml"
    ))
    send_record.save!
    send_record.record_event!(:sent)
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
      send_record.files.attach(create_uploaded_blob(@user, content: file_fixture("sample.txt").read, filename: "sample.txt"))
      send_record.save!
      send_record.record_event!(:sent)
      [ send_record, token ]
    end

    def create_scheduled_send
      send_record = @user.sends.new(recipient_email: "later@example.com", message: "For later.", scheduled_at: 2.days.from_now)
      send_record.files.attach(create_uploaded_blob(@user, filename: "scheduled.txt"))
      send_record.save!
      send_record
    end
end
