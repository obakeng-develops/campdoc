require "test_helper"

class GoogleDriveImportsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "sender@example.com")
  end

  test "signed-in user queues selected Drive files" do
    sign_in_as(@user)

    assert_enqueued_with(job: GoogleDriveImportJob) do
      post api_v1_google_drive_imports_path, params: {
        access_token: "short-lived-token",
        files: [ { id: "drive-file-123", name: "Report.pdf", resource_key: "resource-key" } ]
      }, as: :json
    end

    assert_response :accepted
    drive_import = @user.google_drive_imports.last
    assert_equal "queued", drive_import.status
    assert_equal "Report.pdf", drive_import.filename
    assert_equal files_path, response.parsed_body.fetch("redirect_url")
    assert_not_includes enqueued_jobs.last.fetch(:args).inspect, "short-lived-token"
  end

  test "Drive imports require a Campdoc session" do
    assert_no_difference "GoogleDriveImport.count" do
      post api_v1_google_drive_imports_path, params: valid_params, as: :json
    end

    assert_response :unauthorized
    assert_equal "Sign in to import files.", response.parsed_body.fetch("error")
  end

  test "invalid selections do not queue imports" do
    sign_in_as(@user)

    assert_no_enqueued_jobs do
      post api_v1_google_drive_imports_path, params: valid_params.deep_merge(files: [ { id: "bad", name: "Report.pdf" } ]), as: :json
    end

    assert_response :unprocessable_content
    assert_not @user.google_drive_imports.exists?
  end

  test "machine endpoints use the versioned API namespace" do
    assert_equal "/api/v1/direct_uploads", rails_direct_uploads_path
    assert_equal "/api/v1/google_drive_imports", api_v1_google_drive_imports_path
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/google_drive_imports", method: :post)
    end
  end

  test "My Files shows configured Drive imports and their status" do
    sign_in_as(@user)
    drive_import = @user.google_drive_imports.create!(google_file_id: "drive-file-123", filename: "Report.pdf")

    with_google_drive_enabled do
      get files_path
    end

    assert_response :success
    assert_select "[data-controller='google-drive-picker']"
    assert_select "meta[http-equiv='refresh'][content='3']"
    assert_select ".drive-import", text: /Report.pdf/

    drive_import.fail!("Google access expired.")
    with_google_drive_enabled { get files_path }
    assert_select "meta[http-equiv='refresh']", count: 0
    assert_select ".drive-import--failed", text: /Google access expired/
  end

  private
    def valid_params
      {
        access_token: "short-lived-token",
        files: [ { id: "drive-file-123", name: "Report.pdf" } ]
      }
    end

    def sign_in_as(user)
      login_token, raw_token = LoginToken.issue_for(user)
      post consume_sign_in_path(public_id: login_token.public_id), params: { token: raw_token }
    end

    def with_google_drive_enabled
      previous = Rails.configuration.x.google_drive.enabled
      Rails.configuration.x.google_drive.enabled = true
      yield
    ensure
      Rails.configuration.x.google_drive.enabled = previous
    end
end
