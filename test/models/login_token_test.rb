require "test_helper"

class LoginTokenTest < ActiveSupport::TestCase
  test "tokens work once" do
    user = User.create!(email_address: "sender@example.com")
    token, raw_token = LoginToken.issue_for(user)

    assert_equal user, LoginToken.consume(token.public_id, raw_token)
    assert_nil LoginToken.consume(token.public_id, raw_token)
  end

  test "expired tokens do not work" do
    user = User.create!(email_address: "sender@example.com")
    token, raw_token = LoginToken.issue_for(user)
    token.update!(expires_at: 1.minute.ago)

    assert_nil LoginToken.consume(token.public_id, raw_token)
  end
end
