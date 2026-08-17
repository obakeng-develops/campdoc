class PublishDueDeliveriesJob < ApplicationJob
  WAKE_LEASE = 5.minutes

  def perform
    deliveries = Send.where(published_at: nil, canceled_at: nil, email_status: "pending")
      .where("scheduled_at IS NULL OR scheduled_at <= ?", Time.current)
      .where("publication_enqueued_at IS NULL OR publication_enqueued_at < ?", WAKE_LEASE.ago)
    count = 0
    deliveries.find_each do |delivery|
      claimed = delivery.with_lock do
        next false unless delivery.publication_pending? && delivery.email_status_pending?
        next false if delivery.scheduled_at&.future?
        next false if delivery.publication_enqueued_at && delivery.publication_enqueued_at >= WAKE_LEASE.ago

        delivery.update_column(:publication_enqueued_at, Time.current)
      end
      next unless claimed

      DeliveryEmailJob.perform_later(delivery)
      count += 1
    end
    WideEvent.add(delivery_operation: "publication_sweep", due_delivery_count: count)
  end
end
