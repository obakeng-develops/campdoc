class AuthenticationMailer < ApplicationMailer
  def sign_in
    @login_token = params[:login_token]
    @user = @login_token.user
    @token = params[:token]
    mail to: @user.email_address, subject: "Your Campdoc sign-in link"
  end
end
