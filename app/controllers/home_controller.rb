class HomeController < ApplicationController
  allow_unauthenticated_access

  def show
    return redirect_to new_session_path unless managed_hosting?

    redirect_to files_path if authenticated?
  end

  def pricing
    head :not_found unless managed_hosting?
  end

  def robots
    body = if managed_hosting?
      "User-agent: *\nAllow: /\nDisallow: /d/\nDisallow: /files\nDisallow: /sends\nDisallow: /shared\nDisallow: /session\nDisallow: /sign-in\nSitemap: #{sitemap_url(format: :xml)}\n"
    else
      "User-agent: *\nDisallow: /\n"
    end

    render plain: body
  end

  def sitemap
    head :not_found unless managed_hosting?
  end
end
