class HomeController < ApplicationController
  allow_unauthenticated_access

  def show
    redirect_to new_session_path
  end

  def robots
    render plain: "User-agent: *\nDisallow: /\n"
  end
end
