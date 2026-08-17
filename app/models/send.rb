class Send < ApplicationRecord
  ACCESS_LIFETIME = 30.days
  MAX_FILES = 20
  MAX_SEND_SIZE = 2.gigabytes

  belongs_to :user
  has_secure_token :public_id
  has_many :delivery_revisions, -> { order(number: :asc) }, inverse_of: :delivery, dependent: :destroy, autosave: true
  has_one :latest_revision, -> { order(number: :desc) }, class_name: "DeliveryRevision", inverse_of: :delivery
  has_many :send_events, inverse_of: :delivery, dependent: :delete_all
  enum :email_status, { pending: "pending", sent: "sent", failed: "failed" }, prefix: true, validate: true

  scope :available, -> { where.not(published_at: nil).where(canceled_at: nil, access_revoked_at: nil, access_expires_at: Time.current..).where.not(access_token_digest: nil) }

  normalizes :recipient_email, with: ->(email) { email.strip.downcase }

  validates :recipient_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, length: { maximum: 500 }
  validate :revision_is_valid
  validate :scheduled_at_is_future, if: :will_save_change_to_scheduled_at?
  validate :publication_state_is_consistent

  scope :with_attached_files, -> { includes(latest_revision: { files_attachments: :blob }) }

  def files
    files_revision.files
  end

  def files=(attachables)
    raise ActiveRecord::ReadOnlyRecord, "Published delivery files are immutable" if persisted?

    files.attach(attachables)
  end

  def replace_file!(attachment_id, replacement_blob)
    with_lock do
      current = delivery_revisions.includes(files_attachments: :blob).order(number: :desc).first!
      replaced = current.files.attachments.find(attachment_id)
      blobs = current.files.attachments.map { |attachment| attachment == replaced ? replacement_blob : attachment.blob }
      revision = delivery_revisions.create!(number: current.number + 1, files: blobs)
      association(:latest_revision).reset
      revision
    end
  end

  def published?
    published_at.present?
  end

  def canceled?
    canceled_at.present?
  end

  def publication_pending?
    !published? && !canceled?
  end

  def scheduled?
    publication_pending? && scheduled_at.present?
  end

  def cancel!
    with_lock do
      return false unless publication_pending?

      update!(canceled_at: Time.current)
    end
  end

  def update_before_publication(attributes)
    with_lock do
      return false unless publication_pending?

      update(attributes)
    end
  end

  def issue_access_token(at: Time.current)
    raw_token = SecureRandom.urlsafe_base64(32)
    self.access_token_digest = Digest::SHA256.hexdigest(raw_token)
    self.access_expires_at = at + ACCESS_LIFETIME
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
    published? && !canceled? && access_token_digest.present? && access_revoked_at.nil? && access_expires_at&.future?
  end

  def revoke_access!
    update!(access_revoked_at: Time.current)
  end

  def record_event!(event_type, occurred_at: Time.current)
    event = send_events.find_or_create_by!(event_type: event_type) { |item| item.occurred_at = occurred_at }
    update!(email_status: "sent", published_at: published_at || occurred_at) if event_type.to_s == "sent" && (!email_status_sent? || !published?)
    event
  end

  def status
    %w[downloaded opened sent].find { |event_type| send_events.any? { |event| event.event_type == event_type } }
  end

  def access_state
    return "canceled" if canceled?
    return "revoked" if access_revoked_at?
    return "expired" if access_expires_at&.past?

    "active"
  end

  def display_status
    return "canceled" if canceled?
    return "failed" if email_status_failed?
    return "scheduled" if scheduled?
    return "sending" if email_status_pending?
    return access_state unless access_state == "active"

    status || "sent"
  end

  def recipient_name
    recipient_email.split("@").first.tr("._-", " ").titleize
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token.to_s)
  end
  private_class_method :digest

  private
    def files_revision
      return @initial_revision ||= delivery_revisions.build(number: 1) if new_record?

      latest_revision
    end

    def revision_is_valid
      files_revision.errors.each { |error| errors.import(error) } unless files_revision.valid?
    end

    def scheduled_at_is_future
      errors.add(:scheduled_at, "must be in the future") if scheduled_at.present? && scheduled_at <= Time.current
    end

    def publication_state_is_consistent
      errors.add(:base, "A delivery cannot be published and canceled") if published? && canceled?
    end
end
