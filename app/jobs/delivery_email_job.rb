class DeliveryEmailJob < ApplicationJob
  retry_on Net::SMTPServerBusy, Net::SMTPUnknownError, Net::OpenTimeout, Net::ReadTimeout, SocketError, wait: 10.seconds, attempts: 3

  def perform(delivery)
    # ponytail: the database lock keeps concurrent rotations and revocations ordered; split delivery state out if SMTP latency becomes a write bottleneck.
    delivery.with_lock do
      raw_token = delivery.issue_access_token!
      DeliveryMailer.with(send: delivery, access_token: raw_token).files_ready.deliver_now
      delivery.record_event!(:sent)
    end
  end
end
