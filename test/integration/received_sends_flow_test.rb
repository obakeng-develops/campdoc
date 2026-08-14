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

    get delivery_path(public_id: @delivery.public_id)
    assert_response :success
    assert_select ".delivery-file", count: 1

    post download_delivery_file_path(public_id: @delivery.public_id, id: @delivery.files.first.id)
    assert_response :redirect
  end

  test "another signed-in user still needs the private link" do
    other_user = User.create!(email_address: "other@example.com")
    sign_in_as(other_user)

    get delivery_path(public_id: @delivery.public_id)
    assert_response :success
    assert_select "h1", text: "You have a private delivery."

    get delivery_file_path(public_id: @delivery.public_id, id: @delivery.files.first.id)
    assert_response :not_found
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
    get delivery_path(public_id: expired.public_id)
    assert_response :not_found
  end

  private
    def create_delivery(filename: "contract.txt")
      delivery = @sender.sends.new(recipient_email: "RECIPIENT@example.com", message: "For you.")
      delivery.issue_access_token
      delivery.files.attach(io: StringIO.new(filename), filename: filename, content_type: "text/plain")
      delivery.save!
      delivery
    end

    def sign_in_as(user)
      login_token, raw_token = LoginToken.issue_for(user)
      post consume_sign_in_path(public_id: login_token.public_id), params: { token: raw_token }
    end
end
