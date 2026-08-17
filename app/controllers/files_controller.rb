class FilesController < ApplicationController
  include ServeBlob

  before_action :set_file, only: %i[show preview download destroy]

  def index
    @files = current_user.files.attachments.includes(:blob).order(created_at: :desc)
    @google_drive_imports = current_user.google_drive_imports.visible
  end

  def create
    signed_ids = params.expect(files: []).compact_blank
    blobs = signed_ids.filter_map { |signed_id| ActiveStorage::Blob.find_signed(signed_id) }
    return head :forbidden unless blobs.size == signed_ids.size && blobs.any? && blobs.all? { |blob| blob.uploader_id == current_user.id }

    current_user.retain_files(blobs)
    redirect_to files_path, notice: "Files uploaded."
  end

  def show
  end

  def preview
    return head :unsupported_media_type unless ActiveStorage.web_image_content_types.include?(@file.blob.content_type)

    serve_blob @file.blob, disposition: "inline"
  end

  def download
    serve_blob @file.blob, disposition: "attachment"
  end

  def destroy
    @file.destroy!
    redirect_to files_path, notice: "Removed from My Files."
  end

  private
    def set_file
      @file = current_user.files.attachments.find(params[:id])
    end
end
