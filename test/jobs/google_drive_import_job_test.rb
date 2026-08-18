require "test_helper"

class GoogleDriveImportJobTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "sender@example.com")
    @drive_import = @user.google_drive_imports.create!(google_file_id: "drive-file-123", filename: "Report.pdf")
    @token = GoogleDriveImportJob.encrypt_access_token("short-lived-token")
  end

  test "stores a verified Drive snapshot in My Files" do
    content = "private report"
    job = stubbed_job(content:)

    job.perform(@drive_import, @token)

    assert_equal "completed", @drive_import.reload.status
    assert_equal [ @drive_import.blob_id ], @user.files.blobs.ids
    assert_equal content, @drive_import.blob.download
    assert_match %r{\Ausers/#{@user.id}/blobs/[a-z0-9]{28}\z}, @drive_import.blob.key
  end

  test "rejects native Google Workspace documents" do
    job = stubbed_job(metadata: metadata.merge("mimeType" => "application/vnd.google-apps.document", "size" => nil))

    job.perform(@drive_import, @token)

    assert_equal "failed", @drive_import.reload.status
    assert_match "aren't supported", @drive_import.error
    assert_nil @drive_import.blob
  end

  test "releases reserved storage when verification fails" do
    job = stubbed_job
    job.define_singleton_method(:download) do |*, **|
      raise GoogleDriveImportJob::PermanentError, "Google Drive changed the file while it was importing."
    end

    job.perform(@drive_import, @token)

    assert_equal "failed", @drive_import.reload.status
    assert_nil @drive_import.blob
    assert_equal 0, @user.storage_used
  end

  test "expires queued Google access tokens" do
    expired_token = travel_to(2.hours.ago) { GoogleDriveImportJob.encrypt_access_token("expired") }

    stubbed_job.perform(@drive_import, expired_token)

    assert_equal "failed", @drive_import.reload.status
    assert_match "access expired", @drive_import.error
  end

  test "allows redirects only to Google download hosts" do
    job = GoogleDriveImportJob.new

    assert job.send(:trusted_download_host?, "content.googleapis.com")
    assert job.send(:trusted_download_host?, "download.googleusercontent.com")
    assert_not job.send(:trusted_download_host?, "example.com")
  end

  private
    def stubbed_job(content: "private report", metadata: nil)
      file_metadata = metadata || self.metadata.merge(
        "size" => content.bytesize.to_s,
        "md5Checksum" => Digest::MD5.hexdigest(content)
      )
      job = GoogleDriveImportJob.new
      job.define_singleton_method(:fetch_metadata) { |*, **| file_metadata }
      job.define_singleton_method(:stream_request) do |*, **, &block|
        content.bytes.each_slice(4) { |bytes| block.call(bytes.pack("C*")) }
      end
      job
    end

    def metadata
      {
        "id" => "drive-file-123",
        "name" => "Report.pdf",
        "mimeType" => "application/pdf",
        "capabilities" => { "canDownload" => true }
      }
    end


    def reserve_storage(user, byte_size)
      ActiveStorage::Blob.create_before_direct_upload!(
        filename: "reserved.bin",
        byte_size: byte_size,
        checksum: Base64.strict_encode64(Digest::MD5.digest("reserved")),
        content_type: "application/octet-stream"
      ).update!(uploader_id: user.id)
    end
end
