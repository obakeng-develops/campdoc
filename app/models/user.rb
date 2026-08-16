class User < ApplicationRecord
  PLANS = %w[free pro].freeze
  STORAGE_LIMITS = { "free" => 2.gigabytes, "pro" => 250.gigabytes }.freeze
  MONTHLY_SEND_LIMITS = { "free" => 5, "pro" => nil }.freeze

  has_many :login_tokens, dependent: :delete_all
  has_many :google_drive_imports, dependent: :delete_all
  has_many :sends, dependent: :destroy
  has_many :received_sends, class_name: "Send", foreign_key: :recipient_email, primary_key: :email_address
  has_many :uploaded_blobs, class_name: "ActiveStorage::Blob", foreign_key: :uploader_id, inverse_of: false
  has_many_attached :files

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { case_sensitive: false }
  validates :plan, inclusion: { in: PLANS }

  StorageLimitExceeded = Class.new(StandardError)

  def storage_used
    uploaded_blobs.sum(:byte_size)
  end

  def storage_limit
    STORAGE_LIMITS.fetch(plan)
  end

  def reserve_blob!(**attributes)
    with_lock do
      byte_size = attributes.fetch(:byte_size).to_i
      if Rails.configuration.x.managed_hosting && storage_used + byte_size > storage_limit
        raise StorageLimitExceeded
      end

      key = "users/#{id}/blobs/#{ActiveStorage::Blob.generate_unique_secure_token}"
      ActiveStorage::Blob.create_before_direct_upload!(key: key, **attributes).tap do |blob|
        blob.update!(uploader_id: id)
      end
    end
  end

  def monthly_send_limit
    MONTHLY_SEND_LIMITS.fetch(plan)
  end

  def sends_this_month
    send_usage_month == Time.current.beginning_of_month.to_date ? send_usage_count : 0
  end

  def record_send!
    month = Time.current.beginning_of_month.to_date
    update!(
      send_usage_month: month,
      send_usage_count: send_usage_month == month ? send_usage_count + 1 : 1
    )
  end

  def retain_files(blobs)
    owned_blobs = blobs.select { |blob| blob.uploader_id == id }
    existing_ids = files.blobs.where(id: owned_blobs.map(&:id)).ids
    files.attach(owned_blobs.reject { |blob| blob.id.in?(existing_ids) })
  end
end
