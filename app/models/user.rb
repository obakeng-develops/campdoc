class User < ApplicationRecord
  has_many :login_tokens, dependent: :delete_all
  has_many :sends, dependent: :destroy

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { case_sensitive: false }
end
