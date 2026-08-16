require "test_helper"

class MailerCopyTest < ActionMailer::TestCase
  test "sign-in email explains its single-use link" do
    user = User.create!(email_address: "sender@example.com")
    login_token, raw_token = LoginToken.issue_for(user)
    mail = AuthenticationMailer.with(login_token: login_token, token: raw_token).sign_in

    assert_equal "Your Campdoc sign-in link", mail.subject
    assert_includes mail.text_part.body.decoded, "This single-use link expires in 15 minutes"
    assert_includes mail.text_part.body.decoded, "If you didn’t request this link, ignore this email."
  end

  test "delivery email names one file and explains forwarding" do
    sender = User.create!(email_address: "sender@example.com")
    delivery = sender.sends.new(recipient_email: "sam@example.com", files: [ create_uploaded_blob(sender) ])
    token = delivery.issue_access_token
    delivery.save!
    mail = DeliveryMailer.with(send: delivery, access_token: token).files_ready

    assert_equal "sender@example.com sent you a file", mail.subject
    assert_includes mail.text_part.body.decoded, "View file:"
    assert_includes mail.text_part.body.decoded, "Forwarding the full link shares access."
  end

  test "delivery email pluralizes multiple files" do
    sender = User.create!(email_address: "sender@example.com")
    delivery = sender.sends.new(
      recipient_email: "sam@example.com",
      files: [ create_uploaded_blob(sender), create_uploaded_blob(sender, filename: "second.txt") ]
    )
    token = delivery.issue_access_token
    delivery.save!
    mail = DeliveryMailer.with(send: delivery, access_token: token).files_ready

    assert_equal "sender@example.com sent you 2 files", mail.subject
    assert_includes mail.text_part.body.decoded, "View files:"
  end
end
