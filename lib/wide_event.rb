class WideEvent < ActiveSupport::CurrentAttributes
  attribute :payload, :payload_stack

  class << self
    def start(kind, **fields)
      self.payload_stack = [ *payload_stack, payload ] if payload
      self.payload = {
        event: kind,
        main: true,
        timestamp: Time.current.iso8601(3),
        service_name: "campdoc",
        service_environment: Rails.env,
        service_version: ENV["KAMAL_VERSION"],
        **fields
      }
    end

    def add(**fields)
      payload&.merge!(fields)
    end

    def add_error(error)
      add(error: true, exception_type: error.class.name)
    end

    def emit(**fields)
      return unless payload

      event = payload.merge(fields).compact
      Rails.logger.info JSON.generate(event)
    rescue StandardError
      nil
    ensure
      self.payload = payload_stack&.pop
    end
  end
end
