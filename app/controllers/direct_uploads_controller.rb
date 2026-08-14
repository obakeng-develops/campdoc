class DirectUploadsController < ActiveStorage::DirectUploadsController
  include Authentication
  rate_limit to: 60, within: 1.hour, by: -> { current_user&.id || request.remote_ip }

  def create
    return head :content_too_large if blob_args[:byte_size].to_i > Send::MAX_SEND_SIZE

    blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_args)
    blob.update!(uploader_id: current_user.id)
    render json: direct_upload_json(blob)
  end

  private
    def require_authentication
      head :unauthorized unless authenticated?
    end
end
