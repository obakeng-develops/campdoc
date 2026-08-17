class DeliveryEmailJob < ApplicationJob
  DELIVERY_ERRORS = [ Net::SMTPServerBusy, Net::SMTPUnknownError, Net::OpenTimeout, Net::ReadTimeout, SocketError ].freeze

  retry_on(*DELIVERY_ERRORS, wait: 10.seconds, attempts: 3) do |job, _error|
    job.arguments.first.reload.update!(email_status: "failed")
  end

  def perform(delivery)
    WideEvent.add(user_id: delivery.user_id, delivery_id: delivery.id, email_kind: "delivery")
    # ponytail: the database lock keeps concurrent rotations and revocations ordered; split delivery state out if SMTP latency becomes a write bottleneck.
    delivery.with_lock do
      raw_token = delivery.issue_access_token!
      DeliveryMailer.with(send: delivery, access_token: raw_token).files_ready.deliver_now
      delivery.update!(email_status: "sent")
      delivery.record_event!(:sent)
    end
  rescue *DELIVERY_ERRORS
    raise
  rescue StandardError
    delivery.reload.update!(email_status: "failed")
    raise
  end
end
