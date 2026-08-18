class Collections::FilesController < ApplicationController
  before_action :set_collection

  def create
    attachment = current_user.files.attachments.find(params.expect(:attachment_id))
    @collection.add_file!(attachment)
    redirect_to @collection, notice: "File added."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to @collection, alert: error.record.errors.full_messages.to_sentence
  end

  def destroy
    collection_file = @collection.collection_files.find(params[:id])
    @collection.remove_file!(collection_file)
    redirect_to @collection, notice: "File removed."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to @collection, alert: error.record.errors.full_messages.to_sentence
  end

  private
    def set_collection
      @collection = current_user.collections.active.find(params[:collection_id])
    end
end
