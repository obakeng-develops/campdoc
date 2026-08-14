class AuthenticationEmailJob < ApplicationJob
  def perform(user)
    login_token, raw_token = LoginToken.issue_for(user)
    AuthenticationMailer.with(login_token: login_token, token: raw_token).sign_in.deliver_now
  end
end
