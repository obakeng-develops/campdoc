require "test_helper"

class PublicErrorCopyTest < ActiveSupport::TestCase
  test "public error pages do not expose operator instructions" do
    pages = %w[400.html 404.html 406-unsupported-browser.html 422.html 500.html]

    pages.each do |page|
      copy = Rails.root.join("public", page).read
      assert_no_match "application owner", copy
      assert_no_match "check the logs", copy
    end
  end
end
