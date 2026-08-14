class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 5, within: 15.minutes, only: :create, name: "ip"
  rate_limit to: 5, within: 15.minutes, only: :create, name: "email", by: -> { params[:email_address].to_s.strip.downcase }

  def new
    redirect_to sends_path if authenticated?
  end

  def create
    email_address = params.expect(:email_address).to_s.strip.downcase
    user = User.find_or_create_by!(email_address: email_address)
    AuthenticationEmailJob.perform_later(user)

    redirect_to new_session_path, notice: "Check your email. Your sign-in link is on its way."
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = "Enter a valid email address."
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def destroy
    reset_session
    redirect_to(managed_hosting? ? root_path : new_session_path, notice: "You’re signed out.")
  end
end
