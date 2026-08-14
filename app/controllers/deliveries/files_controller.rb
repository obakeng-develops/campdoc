class Deliveries::FilesController < ApplicationController
  include DeliveryAccess
  include ServeBlob

  allow_unauthenticated_access
  before_action :require_delivery_access
  rate_limit to: 120, within: 1.minute, by: -> { request.remote_ip }

  def show
    attachment = find_attachment
    return head :unsupported_media_type unless ActiveStorage.web_image_content_types.include?(attachment.blob.content_type)

    serve_blob attachment.blob, disposition: "inline"
  end

  def download
    attachment = find_attachment
    @send.record_event!(:downloaded)

    serve_blob attachment.blob, disposition: "attachment"
  end

  private
    def find_attachment
      @send.files.attachments.find(params[:id])
    end
end
