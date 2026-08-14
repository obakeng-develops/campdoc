class User < ApplicationRecord
  has_many :login_tokens, dependent: :delete_all
  has_many :sends, dependent: :destroy
  has_many :received_sends, class_name: "Send", foreign_key: :recipient_email, primary_key: :email_address
  has_many_attached :files

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { case_sensitive: false }

  def retain_files(blobs)
    owned_blobs = blobs.select { |blob| blob.uploader_id == id }
    existing_ids = files.blobs.where(id: owned_blobs.map(&:id)).ids
    files.attach(owned_blobs.reject { |blob| blob.id.in?(existing_ids) })
  end
end
