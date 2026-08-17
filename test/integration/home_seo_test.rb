require "test_helper"

class HomeSeoTest < ActionDispatch::IntegrationTest
  setup do
    host! "campsend.app"
    https!
  end

  test "managed marketing pages are indexable" do
    with_managed_hosting do
      get root_path

      assert_response :success
      assert_select "meta[name='robots'][content='index, follow']"
      assert_select "meta[name='description'][content*='Send files free']"
      assert_select "link[rel='canonical'][href='https://campsend.app/']"
      assert_select "meta[property='og:url'][content='https://campsend.app/']"
      assert_select "script[type='application/ld+json']", text: /SoftwareApplication/

      get pricing_path

      assert_select "link[rel='canonical'][href='https://campsend.app/pricing']"
    end
  end

  test "application pages are not indexable" do
    with_managed_hosting do
      get new_session_path

      assert_response :success
      assert_select "meta[name='robots'][content='noindex, nofollow']"
      assert_select "link[rel='canonical']", count: 0
    end
  end

  test "managed hosting publishes robots and sitemap" do
    with_managed_hosting do
      get "/robots.txt"

      assert_response :success
      assert_includes response.body, "Disallow: /d/"
      assert_includes response.body, "Sitemap: https://campsend.app/sitemap.xml"

      get "/sitemap.xml"

      assert_response :success
      assert_includes response.body, "https://campsend.app/"
      assert_includes response.body, "https://campsend.app/pricing"
    end
  end

  test "self-hosted installations block crawlers" do
    get "/robots.txt"

    assert_response :success
    assert_equal "User-agent: *\nDisallow: /\n", response.body

    get "/sitemap.xml"

    assert_response :not_found
  end
end
