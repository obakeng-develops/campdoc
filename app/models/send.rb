class Send < ApplicationRecord
  ACCESS_LIFETIME = 30.days
  MAX_FILES = 20
  MAX_SEND_SIZE = 2.gigabytes

  belongs_to :user
  has_secure_token :public_id
  has_many_attached :files
  has_many :send_events, inverse_of: :delivery, dependent: :delete_all

  scope :available, -> { where(access_revoked_at: nil, access_expires_at: Time.current..).where.not(access_token_digest: nil) }

  normalizes :recipient_email, with: ->(email) { email.strip.downcase }

  validates :recipient_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, length: { maximum: 500 }
  validate :files_are_attached
  validate :files_are_within_limits
  validate :files_belong_to_sender

  def issue_access_token
    raw_token = SecureRandom.urlsafe_base64(32)
    self.access_token_digest = Digest::SHA256.hexdigest(raw_token)
    self.access_expires_at = ACCESS_LIFETIME.from_now
    self.access_revoked_at = nil
    raw_token
  end

  def issue_access_token!
    raw_token = issue_access_token
    save!
    raw_token
  end

  def self.find_by_access_token(public_id, raw_token)
    delivery = find_by(public_id: public_id, access_token_digest: digest(raw_token))
    delivery if delivery&.access_active?
  end

  def access_active?
    access_token_digest.present? && access_revoked_at.nil? && access_expires_at&.future?
  end

  def revoke_access!
    update!(access_revoked_at: Time.current)
  end

  def record_event!(event_type)
    send_events.find_or_create_by!(event_type: event_type) { |event| event.occurred_at = Time.current }
  end

  def status
    %w[downloaded opened sent].find { |event_type| send_events.any? { |event| event.event_type == event_type } }
  end

  def recipient_name
    recipient_email.split("@").first.tr("._-", " ").titleize
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token.to_s)
  end
  private_class_method :digest

  private
    def files_are_attached
      errors.add(:files, "Choose at least one file") unless files.attached?
    end

    def files_are_within_limits
      errors.add(:files, "Choose no more than #{MAX_FILES} files") if files.size > MAX_FILES
      errors.add(:files, "Must total less than 2 GB") if files.sum(&:byte_size) > MAX_SEND_SIZE
    end

    def files_belong_to_sender
      return unless user

      errors.add(:files, "Include a file uploaded by another account") if files.any? { |file| file.blob.uploader_id.present? && file.blob.uploader_id != user_id }
    end
end
