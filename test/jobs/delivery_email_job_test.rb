require "test_helper"

class DeliveryEmailJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    user = User.create!(email_address: "sender@example.com")
    @delivery = user.sends.new(recipient_email: "sam@example.com")
    @delivery.files.attach(create_uploaded_blob(user))
    @delivery.save!
  end

  test "records sent only after email delivery succeeds" do
    DeliveryEmailJob.perform_now(@delivery)

    assert_equal "sent", @delivery.reload.status
    assert @delivery.email_status_sent?
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
    assert @delivery.email_status_failed?
  ensure
    DeliveryMailer.define_singleton_method(:with, original_with) if original_with
  end

  test "marks email failed after retries are exhausted" do
    failing_mailer = Object.new
    failing_mailer.define_singleton_method(:files_ready) { raise Net::SMTPServerBusy, "SMTP busy" }
    original_with = DeliveryMailer.method(:with)
    DeliveryMailer.define_singleton_method(:with) { |**| failing_mailer }

    perform_enqueued_jobs { DeliveryEmailJob.perform_later(@delivery) }

    assert @delivery.reload.email_status_failed?
    assert_nil @delivery.status
  ensure
    DeliveryMailer.define_singleton_method(:with, original_with) if original_with
  end
end
