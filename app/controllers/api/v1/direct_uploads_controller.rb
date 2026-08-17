class Api::V1::DirectUploadsController < ActiveStorage::DirectUploadsController
  include Authentication
  rate_limit to: 60, within: 1.hour, by: -> { current_user&.id || request.remote_ip }

  def create
    if blob_args[:byte_size].to_i > Send::MAX_SEND_SIZE
      return render json: { error: "File exceeds Campsend's 2 GB limit." }, status: :content_too_large
    end

    blob = current_user.reserve_blob!(**blob_args)
    WideEvent.add(blob_id: blob.id, upload_bytes: blob.byte_size)
    render json: direct_upload_json(blob)
  rescue User::StorageLimitExceeded
    WideEvent.add(outcome: "storage_limit")
    render json: { error: "Storage limit reached. Remove files before uploading more." }, status: :unprocessable_content
  end

  private
    def require_authentication
      render json: { error: "Sign in to upload files." }, status: :unauthorized unless authenticated?
    end
end
