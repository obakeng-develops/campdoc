require_relative "boot"

require "rails/all"
require_relative "../lib/campsend"
require_relative "../lib/campsend/policy"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Campsend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Files are only exposed through Campsend's authorization and tracking endpoints.
    config.active_storage.draw_routes = false
    config.x.google_drive.client_id = ENV["GOOGLE_DRIVE_CLIENT_ID"]
    config.x.google_drive.api_key = ENV["GOOGLE_DRIVE_API_KEY"]
    config.x.google_drive.app_id = ENV["GOOGLE_DRIVE_APP_ID"]
    config.x.google_drive.enabled = [
      config.x.google_drive.client_id,
      config.x.google_drive.api_key,
      config.x.google_drive.app_id
    ].all?(&:present?)
    config.x.extension_stylesheets = []
    config.x.recipient_delivery_partials = []
    config.x.sender_delivery_partials = []

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
