class WideEventMiddleware
  SKIP_PREFIXES = %w[/up /assets /icon].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    skipped = skip?(request)

    WideEvent.start(:request,
      request_id: request.request_id,
      method: request.request_method,
      path: request.path,
      ip: request.remote_ip,
      user_agent: request.user_agent.to_s.truncate(200)) unless skipped

    status, headers, body = @app.call(env)
    if !skipped && WideEvent.payload
      WideEvent.add(route: route_pattern(request), status: status)
      WideEvent.add(outcome: outcome(status)) unless WideEvent.payload.key?(:outcome)
    end
    [ status, headers, body ]
  rescue => error
    WideEvent.add(status: 500, outcome: "error")
    WideEvent.add_error(error)
    raise
  ensure
    unless skipped
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)
      WideEvent.emit(duration_ms: duration_ms)
    end
  end

  private
    def skip?(request)
      SKIP_PREFIXES.any? { |prefix| request.path.start_with?(prefix) }
    end

    def route_pattern(request)
      request.route_uri_pattern
    rescue ActionController::RoutingError, NoMethodError
      nil
    end

    def outcome(status)
      return "error" if status >= 500
      return "client_error" if status >= 400

      "success"
    end
end
