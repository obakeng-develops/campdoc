require Rails.root.join("lib/wide_event")
require Rails.root.join("lib/wide_event_middleware")

Rails.application.config.middleware.use WideEventMiddleware
