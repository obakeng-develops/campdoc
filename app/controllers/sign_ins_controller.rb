class SignInsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_private_cache

  def show
    @login_token = LoginToken.find_by(public_id: params[:public_id])
    redirect_to new_session_path, alert: "That sign-in link has expired. Ask for a new one." unless @login_token&.usable?
  end

  def create
    login_token = LoginToken.find_by(public_id: params[:public_id])
    user = LoginToken.consume(params[:public_id], params[:token])

    if user
      reset_session
      session[:user_id] = user.id
      session[:authenticated_at] = Time.current.to_i
      redirect_to(login_token&.intent == "send" ? new_send_path : files_path, notice: "Signed in.")
    else
      redirect_to new_session_path, alert: "That sign-in link has expired. Ask for a new one."
    end
  end

  private
    def set_private_cache
      response.headers["Cache-Control"] = "private, no-store"
    end
end
