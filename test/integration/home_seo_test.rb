require "test_helper"

class HomeSeoTest < ActionDispatch::IntegrationTest
  test "application pages are not indexable" do
    get new_session_path

    assert_response :success
    assert_select "meta[name='robots'][content='noindex, nofollow']"
    assert_select "link[rel='canonical']", count: 0
  end

  test "self-hosted installations block crawlers and have no sitemap" do
    get "/robots.txt"

    assert_response :success
    assert_equal "User-agent: *\nDisallow: /\n", response.body

    get "/sitemap.xml"

    assert_response :not_found
  end
end
