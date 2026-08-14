require "test_helper"

class DeliveryEmailJobTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email_address: "sender@example.com")
    @delivery = user.sends.new(recipient_email: "sam@example.com")
    @delivery.files.attach(io: StringIO.new("hello"), filename: "hello.txt", content_type: "text/plain")
    @delivery.save!
  end

  test "records sent only after email delivery succeeds" do
    DeliveryEmailJob.perform_now(@delivery)

    assert_equal "sent", @delivery.reload.status
    assert @delivery.access_active?
  end

  test "rolls token rotation back when email delivery fails" do
    original_token = @delivery.issue_access_token!
    failing_mailer = Object.new
    failing_mailer.define_singleton_method(:files_ready) { raise "SMTP failed" }
    original_with = DeliveryMailer.method(:with)
    DeliveryMailer.define_singleton_method(:with) { |**| failing_mailer }

    assert_raises(RuntimeError) { DeliveryEmailJob.new.perform(@delivery) }

    assert Send.find_by_access_token(@delivery.public_id, original_token)
    assert_nil @delivery.reload.status
  ensure
    DeliveryMailer.define_singleton_method(:with, original_with) if original_with
  end
end
