class SendsController < ApplicationController
  before_action :set_send, only: %i[show revoke_access rotate_access]
  rate_limit to: 20, within: 1.hour, only: :create, by: -> { current_user.id }

  def index
    @sends = current_user.sends.with_attached_files.includes(:send_events).order(created_at: :desc)
  end

  def new
    @send = current_user.sends.new
    set_library_files
  end

  def create
    @send = current_user.sends.new(send_params)
    if @send.save
      current_user.retain_files(@send.files.blobs)
      DeliveryEmailJob.perform_later(@send)
      redirect_to @send, notice: "You’re all set. #{@send.recipient_name} has something lovely waiting."
    else
      set_library_files
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def revoke_access
    @send.revoke_access!
    redirect_to @send, notice: "Recipient access has been revoked."
  end

  def rotate_access
    DeliveryEmailJob.perform_later(@send)
    redirect_to @send, notice: "A fresh private link is on its way."
  end

  private
    def set_send
      @send = current_user.sends.with_attached_files.includes(:send_events).find(params[:id])
    end

    def send_params
      params.expect(send: [ :recipient_email, :message, files: [] ])
    end

    def set_library_files
      files = current_user.files.attachments.includes(:blob).order(created_at: :desc)
      selected_file = files.find_by(id: params[:file_id])
      @library_files = [ selected_file, *files.where.not(id: selected_file&.id).limit(11) ].compact
      @selected_file_id = selected_file&.id
    end
end
