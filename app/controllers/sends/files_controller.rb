class Sends::FilesController < ApplicationController
  include ServeBlob

  def show
    send_record = current_user.sends.find(params[:send_id])
    attachment = send_record.files.attachments.find(params[:id])
    disposition = ActiveStorage.web_image_content_types.include?(attachment.blob.content_type) ? "inline" : "attachment"

    serve_blob attachment.blob, disposition: disposition
  end
end
