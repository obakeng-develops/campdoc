class HomeController < ApplicationController
  allow_unauthenticated_access

  def show
    redirect_to sends_path if authenticated?
  end

  def pricing
  end
end
