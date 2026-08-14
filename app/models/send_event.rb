class SendEvent < ApplicationRecord
  belongs_to :delivery, class_name: "Send", foreign_key: :send_id, inverse_of: :send_events

  enum :event_type, { sent: "sent", opened: "opened", downloaded: "downloaded" }, validate: true

  validates :occurred_at, presence: true
end
