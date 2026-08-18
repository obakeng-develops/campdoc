require "test_helper"

class ReceivedSendsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @sender = User.create!(email_address: "sender@example.com")
    @recipient = User.create!(email_address: "recipient@example.com")
    @delivery = create_delivery
  end

  test "matching recipient sees and opens an active delivery without its bearer token" do
    sign_in_as(@recipient)

    get shared_files_path
    assert_response :success
    assert_select ".send-card", count: 1
    assert_select ".send-card", text: /contract.txt/
    assert_select ".send-card", text: /sender@example.com/
    assert_select ".delivery-expiry", text: /Until/

    get delivery_path(public_id: @delivery.public_id)
    assert_response :success
    assert_select ".delivery-file", count: 1

    post download_delivery_file_path(public_id: @delivery.public_id, id: @delivery.files.first.id)
    assert_response :redirect
  end

  test "another signed-in user still needs the complete delivery link" do
    other_user = User.create!(email_address: "other@example.com")
    sign_in_as(other_user)

    get delivery_path(public_id: @delivery.public_id)
    assert_response :success
    assert_select "h1", text: "sender@example.com sent you a delivery."

    get delivery_file_path(public_id: @delivery.public_id, id: @delivery.files.first.id)
    assert_response :not_found
  end

  test "Shared with me uses a delivery slug when present" do
    @delivery.update_column(:slug, "shared-contract")
    sign_in_as(@recipient)

    get shared_files_path

    assert_select "a.send-card[href='#{delivery_path(public_id: "shared-contract")}']"
  end

  test "revoked and expired deliveries leave Shared with me" do
    revoked = create_delivery(filename: "revoked.txt")
    revoked.revoke_access!
    expired = create_delivery(filename: "expired.txt")
    expired.update!(access_expires_at: 1.minute.ago)
    sign_in_as(@recipient)

    get shared_files_path

    assert_response :success
    assert_select ".send-card", count: 1
    assert_select ".send-card", text: /contract.txt/

    get delivery_path(public_id: revoked.public_id)
    assert_response :not_found
    assert_select "h1", text: "This delivery is no longer available."
    get delivery_path(public_id: expired.public_id)
    assert_response :not_found
    assert_select "h1", text: "This delivery is no longer available."
  end


  test "unpublished and canceled deliveries stay out of Shared with me" do
    scheduled = @sender.sends.new(recipient_email: @recipient.email_address, scheduled_at: 2.days.from_now)
    scheduled.files.attach(create_uploaded_blob(@sender, filename: "scheduled.txt"))
    scheduled.save!
    canceled = @sender.sends.new(recipient_email: @recipient.email_address, scheduled_at: 2.days.from_now)
    canceled.files.attach(create_uploaded_blob(@sender, filename: "canceled.txt"))
    canceled.save!
    canceled.cancel!
    sign_in_as(@recipient)

    get shared_files_path

    assert_response :success
    assert_select ".send-card", count: 1
    assert_select ".send-card", text: /contract.txt/
    get delivery_path(public_id: scheduled.public_id)
    assert_select "h1", text: "This delivery isn’t available yet."
    get delivery_path(public_id: canceled.public_id)
    assert_select "h1", text: "This delivery is no longer available."
  end

  private
    def create_delivery(filename: "contract.txt")
      delivery = @sender.sends.new(recipient_email: "RECIPIENT@example.com", message: "For you.")
      delivery.issue_access_token
      delivery.files.attach(create_uploaded_blob(@sender, content: filename, filename: filename))
      delivery.save!
      delivery.record_event!(:sent)
      delivery
    end

    def sign_in_as(user)
      login_token, raw_token = LoginToken.issue_for(user)
      post consume_sign_in_path(public_id: login_token.public_id), params: { token: raw_token }
    end
end
