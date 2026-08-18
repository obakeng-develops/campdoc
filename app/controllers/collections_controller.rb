class CollectionsController < ApplicationController
  before_action :set_collection, only: %i[show update destroy]

  def index
    @collection = current_user.collections.new
    @collections = current_user.collections.active.includes(:blobs).order(:name)
  end

  def show
    member_blob_ids = @collection.collection_files.select(:blob_id)
    @available_files = current_user.files.attachments.includes(:blob).where.not(blob_id: member_blob_ids).order(created_at: :desc)
  end

  def create
    @collection = current_user.collections.new(collection_params)
    if @collection.save
      redirect_to @collection, notice: "Collection created."
    else
      @collections = current_user.collections.active.includes(:blobs).order(:name)
      render :index, status: :unprocessable_content
    end
  end

  def update
    @collection.rename!(collection_params[:name])
    redirect_to @collection, notice: "Collection renamed."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to @collection, alert: error.record.errors.full_messages.to_sentence
  end

  def destroy
    @collection.remove!
    redirect_to collections_path, notice: "Collection removed. Existing deliveries are unchanged."
  end

  private
    def set_collection
      @collection = current_user.collections.active.find(params[:id])
    end

    def collection_params
      params.expect(collection: [ :name ])
    end
end
