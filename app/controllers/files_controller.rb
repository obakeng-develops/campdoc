class FilesController < ApplicationController
  include ServeBlob

  before_action :set_file, only: %i[show download destroy]

  def index
    @files = current_user.files.attachments.includes(:blob).order(created_at: :desc)
  end

  def create
    signed_ids = params.expect(files: []).compact_blank
    blobs = signed_ids.filter_map { |signed_id| ActiveStorage::Blob.find_signed(signed_id) }
    return head :forbidden unless blobs.size == signed_ids.size && blobs.any? && blobs.all? { |blob| blob.uploader_id == current_user.id }

    current_user.retain_files(blobs)
    redirect_to files_path, notice: "Your files are ready."
  end

  def show
    disposition = ActiveStorage.web_image_content_types.include?(@file.blob.content_type) ? "inline" : "attachment"
    serve_blob @file.blob, disposition: disposition
  end

  def download
    serve_blob @file.blob, disposition: "attachment"
  end

  def destroy
    @file.destroy!
    redirect_to files_path, notice: "File removed from My Files."
  end

  private
    def set_file
      @file = current_user.files.attachments.find(params[:id])
    end
end
