class HomeController < ApplicationController
  allow_unauthenticated_access

  def show
    return redirect_to new_session_path unless managed_hosting?

    redirect_to sends_path if authenticated?
  end

  def pricing
    head :not_found unless managed_hosting?
  end
end
