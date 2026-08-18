class ApplicationController < ActionController::Base
  include ActiveStorage::SetCurrent
  include Authentication
  helper_method :google_drive_enabled?

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    def google_drive_enabled?
      Rails.configuration.x.google_drive.enabled
    end
end
