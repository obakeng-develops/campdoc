class GoogleDriveImport < ApplicationRecord
  STATUSES = %w[queued importing completed failed].freeze

  belongs_to :user
  belongs_to :blob, class_name: "ActiveStorage::Blob", optional: true

  validates :google_file_id, format: { with: /\A[A-Za-z0-9_-]{10,255}\z/ }
  validates :filename, presence: true, length: { maximum: 255 }
  validates :resource_key, length: { maximum: 255 }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }

  scope :visible, -> { where(status: %w[queued importing failed]).order(created_at: :desc) }
  scope :active, -> { where(status: %w[queued importing]) }

  def fail!(message)
    update!(status: "failed", error: message.to_s.truncate(255))
  end
end
