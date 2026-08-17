class DeliveryAccessEmailJob < ApplicationJob
  retry_on(*DeliveryEmailJob::DELIVERY_ERRORS, wait: 10.seconds, attempts: 3) do |job, _error|
    job.arguments.first.reload.update!(email_status: "failed")
  end

  def perform(delivery)
    WideEvent.add(user_id: delivery.user_id, delivery_id: delivery.id, email_kind: "access_rotation")
    delivery.with_lock do
      unless delivery.published? && !delivery.canceled?
        WideEvent.add(email_outcome: "unavailable")
        next
      end

      raw_token = delivery.issue_access_token!
      DeliveryMailer.with(send: delivery, access_token: raw_token).files_ready.deliver_now
      delivery.update!(email_status: "sent")
      WideEvent.add(email_outcome: "sent")
    end
  rescue *DeliveryEmailJob::DELIVERY_ERRORS
    raise
  rescue StandardError
    delivery.reload.update!(email_status: "failed")
    raise
  end
end
