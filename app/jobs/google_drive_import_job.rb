require "base64"
require "digest"
require "json"
require "net/http"
require "tempfile"
require "uri"

class GoogleDriveImportJob < ApplicationJob
  class PermanentError < StandardError; end
  class TransientError < StandardError; end

  NETWORK_ERRORS = [ Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET ].freeze
  GOOGLE_API = "https://www.googleapis.com/drive/v3/files".freeze

  retry_on TransientError, *NETWORK_ERRORS, wait: 10.seconds, attempts: 3 do |job, _error|
    job.arguments.first.tap do |drive_import|
      drive_import.blob&.purge
      drive_import.fail!("Google Drive didn't finish the import. Try again.")
    end
  end

  def self.encrypt_access_token(token)
    encryptor.encrypt_and_sign({ token:, expires_at: 1.hour.from_now.to_i }, purpose: :google_drive_import)
  end

  def self.decrypt_access_token(token)
    payload = encryptor.decrypt_and_verify(token, purpose: :google_drive_import)
    raise ActiveSupport::MessageEncryptor::InvalidMessage if payload.fetch("expires_at") < Time.current.to_i

    payload.fetch("token")
  end

  def perform(drive_import, encrypted_token)
    WideEvent.add(user_id: drive_import.user_id, import_id: drive_import.id, import_provider: "google_drive")
    return if drive_import.status == "completed"

    drive_import.update!(status: "importing", error: nil)
    if drive_import.blob&.service&.exist?(drive_import.blob.key)
      finish_import(drive_import)
      return
    end

    token = self.class.decrypt_access_token(encrypted_token)
    metadata = fetch_metadata(drive_import, token)
    validate_metadata!(metadata)
    blob = drive_import.blob || reserve_blob(drive_import, metadata)
    drive_import.update!(blob: blob, filename: filename(metadata))
    WideEvent.add(import_id: drive_import.id, import_bytes: Integer(metadata.fetch("size")))

    download(drive_import, metadata, token) do |file, checksum|
      blob.update!(checksum: checksum)
      blob.upload_without_unfurling(file)
    end
    finish_import(drive_import)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    fail_import(drive_import, "Google access expired. Open Drive and try again.")
  rescue PermanentError => error
    fail_import(drive_import, error.message)
  rescue TransientError, *NETWORK_ERRORS
    raise
  rescue StandardError
    fail_import(drive_import, "The Google Drive import failed. Try again.")
    raise
  end

  private
    def fetch_metadata(drive_import, token)
      uri = URI("#{GOOGLE_API}/#{drive_import.google_file_id}")
      uri.query = URI.encode_www_form(
        fields: "id,name,size,mimeType,md5Checksum,capabilities(canDownload)",
        supportsAllDrives: true
      )
      response = request(uri, token:, resource_key: drive_import.resource_key)
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise TransientError, "Google Drive returned an invalid response"
    end

    def validate_metadata!(metadata)
      mime_type = metadata.fetch("mimeType", "")
      raise PermanentError, "Google Docs, Sheets, and Slides aren't supported yet." if mime_type.start_with?("application/vnd.google-apps.")
      raise PermanentError, "Google Drive doesn't allow this file to be downloaded." unless metadata.dig("capabilities", "canDownload")

      size = Integer(metadata["size"], exception: false)
      raise PermanentError, "Google Drive didn't provide this file's size." unless size
      raise PermanentError, "This file is larger than Campsend's 2 GB limit." if size > Send::MAX_SEND_SIZE
      raise PermanentError, "Google Drive didn't provide this file's name." if metadata["name"].blank?
      if metadata["md5Checksum"].present? && !metadata["md5Checksum"].match?(/\A[0-9a-f]{32}\z/i)
        raise PermanentError, "Google Drive returned an invalid file checksum."
      end
    end

    def reserve_blob(drive_import, metadata)
      checksum = checksum_from_hex(metadata["md5Checksum"])
      drive_import.user.reserve_blob!(
        filename: filename(metadata),
        byte_size: Integer(metadata.fetch("size")),
        checksum: checksum,
        content_type: metadata["mimeType"]
      )
    rescue User::StorageLimitExceeded
      raise PermanentError, "Storage limit reached. Remove files before importing more."
    end

    def download(drive_import, metadata, token)
      uri = URI("#{GOOGLE_API}/#{drive_import.google_file_id}")
      uri.query = URI.encode_www_form(alt: "media", supportsAllDrives: true)
      expected_size = Integer(metadata.fetch("size"))
      expected_checksum = checksum_from_hex(metadata["md5Checksum"])
      file = Tempfile.new([ "campsend-drive-", ".download" ], binmode: true)
      digest = Digest::MD5.new
      bytes = 0

      stream_request(uri, token:, resource_key: drive_import.resource_key) do |chunk|
        bytes += chunk.bytesize
        raise PermanentError, "The downloaded file exceeded Campsend's 2 GB limit." if bytes > Send::MAX_SEND_SIZE

        digest.update(chunk)
        file.write(chunk)
      end

      raise PermanentError, "Google Drive changed the file while it was importing." unless bytes == expected_size

      checksum = Base64.strict_encode64(digest.digest)
      raise PermanentError, "Google Drive changed the file while it was importing." if expected_checksum && checksum != expected_checksum

      file.rewind
      yield file, checksum
    ensure
      file&.close!
    end

    def request(uri, token:, resource_key: nil)
      response = perform_request(uri, token:, resource_key:)
      raise_for_status!(response)
      response
    end

    def stream_request(uri, token:, resource_key:, redirects: 0, &block)
      perform_request(uri, token:, resource_key:, stream: true) do |response|
        if response.is_a?(Net::HTTPRedirection)
          raise PermanentError, "Google Drive returned too many redirects." if redirects >= 1

          location = response["location"]
          raise PermanentError, "Google Drive returned an invalid download location." if location.blank?

          redirected_uri = URI.join(uri, location)
          unless redirected_uri.scheme == "https" && trusted_download_host?(redirected_uri.host)
            raise PermanentError, "Google Drive returned an unsafe download location."
          end

          return stream_request(redirected_uri, token: nil, resource_key: nil, redirects: redirects + 1, &block)
        end

        raise_for_status!(response)
        response.read_body(&block)
      end
    end

    def perform_request(uri, token:, resource_key:, stream: false)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{token}" if token
      request["X-Goog-Drive-Resource-Keys"] = resource_key_header(uri, resource_key) if resource_key

      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
        if stream
          http.request(request) { |response| yield response }
        else
          http.request(request)
        end
      end
    end

    def raise_for_status!(response)
      case response
      when Net::HTTPSuccess
        nil
      when Net::HTTPTooManyRequests, Net::HTTPServerError
        raise TransientError, "Google Drive is temporarily unavailable"
      when Net::HTTPUnauthorized
        raise PermanentError, "Google access expired. Open Drive and try again."
      when Net::HTTPForbidden
        raise PermanentError, "Google Drive doesn't allow this file to be downloaded."
      when Net::HTTPNotFound
        raise PermanentError, "This Google Drive file is no longer available."
      else
        raise PermanentError, "Google Drive couldn't import this file."
      end
    end

    def resource_key_header(uri, resource_key)
      file_id = uri.path.split("/").last
      "#{file_id}/#{resource_key}"
    end

    def trusted_download_host?(host)
      host == "content.googleapis.com" || host&.end_with?(".googleusercontent.com")
    end

    def checksum_from_hex(checksum)
      Base64.strict_encode64([ checksum ].pack("H*")) if checksum.present?
    end

    def filename(metadata)
      metadata.fetch("name").delete("\0").truncate(255)
    end

    def finish_import(drive_import)
      drive_import.user.retain_files([ drive_import.blob ])
      drive_import.update!(status: "completed", error: nil)
      WideEvent.add(import_id: drive_import.id, import_status: "completed")
    end

    def fail_import(drive_import, message)
      drive_import.blob&.purge
      drive_import.fail!(message)
      WideEvent.add(import_id: drive_import.id, import_status: "failed", import_error: message.to_s.truncate(200))
    end

    def self.encryptor
      key = Rails.application.key_generator.generate_key("google-drive-import", ActiveSupport::MessageEncryptor.key_len)
      ActiveSupport::MessageEncryptor.new(key)
    end
end
