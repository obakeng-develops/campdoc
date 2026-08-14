class LoginToken < ApplicationRecord
  LIFETIME = 15.minutes

  belongs_to :user
  has_secure_token :public_id

  def self.issue_for(user)
    raw_token = SecureRandom.urlsafe_base64(32)
    token = create!(user: user, token_digest: digest(raw_token), expires_at: LIFETIME.from_now)
    [ token, raw_token ]
  end

  def self.consume(public_id, raw_token)
    token = find_by(public_id: public_id, token_digest: digest(raw_token))
    return unless token

    token.with_lock do
      return if token.used_at? || token.expires_at.past?

      token.update!(used_at: Time.current)
      token.user
    end
  end

  def usable?
    !used_at? && expires_at.future?
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token.to_s)
  end
  private_class_method :digest
end
