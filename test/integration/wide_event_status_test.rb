require "test_helper"

class WideEventStatusTest < ActionDispatch::IntegrationTest
  # The wide event is what triage reads, so the status it reports has to be the status
  # the client received. Rails renders many exceptions as 4xx, and reporting those as
  # 500 makes ordinary rejections look like faults in the one place used to tell them
  # apart.
  test "a rejected form reports the status the client actually got" do
    event = capture_wide_event do
      with_forgery_protection do
        post session_path, params: { email_address: "someone@example.com", authenticity_token: "stale" }
      end
    end

    assert_response :unprocessable_content
    assert_equal response.status, event["status"]
    assert_equal "client_error", event["outcome"]
    assert_equal "ActionController::InvalidAuthenticityToken", event["exception_type"]
  end

  private
    def with_forgery_protection
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    def capture_wide_event
      output = StringIO.new
      original = Rails.logger
      Rails.logger = ActiveSupport::TaggedLogging.new(Logger.new(output))
      yield
      output.rewind
      output.read.lines.filter_map { |line| JSON.parse(line.sub(/\A\[[^\]]*\] /, "")) rescue nil }
            .find { |event| event["event"] == "request" }
    ensure
      Rails.logger = original
    end
end
