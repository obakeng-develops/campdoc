class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 5, within: 15.minutes, only: :create, name: "ip"
  rate_limit to: 5, within: 15.minutes, only: :create, name: "email", by: -> { params[:email_address].to_s.strip.downcase }

  def new
    redirect_to(params[:intent] == "send" ? new_send_path : files_path) if authenticated?
    session.delete(:sign_in_email) if params[:change_email]
    @sign_in_email = session[:sign_in_email]
  end

  def create
    email_address = params.expect(:email_address).to_s.strip.downcase
    intent = params[:intent] == "send" ? "send" : nil
    user = User.find_or_create_by!(email_address: email_address)
    AuthenticationEmailJob.perform_later(user, intent)

    session[:sign_in_email] = email_address
    redirect_to new_session_path(intent: intent)
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = "Enter a valid email address."
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def destroy
    reset_session
    redirect_to root_path
  end
end
