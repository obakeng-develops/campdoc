class SendsController < ApplicationController
  before_action :set_send, only: %i[show destroy revoke_access rotate_access]
  rate_limit to: 20, within: 1.hour, only: :create, by: -> { current_user.id }

  def index
    @sends = current_user.sends.with_attached_files.includes(:send_events).order(created_at: :desc)
  end

  def new
    @send = current_user.sends.new
    set_library_files
  end

  def create
    return head :bad_request if Array(params.dig(:send, :files)).any? { |file| !file.is_a?(String) }

    @send = current_user.sends.new(send_params)
    if save_send
      blobs = @send.files.blobs.to_a
      WideEvent.add(send_id: @send.id, file_count: blobs.size, send_bytes: blobs.sum(&:byte_size))
      current_user.retain_files(blobs)
      DeliveryEmailJob.perform_later(@send)
      redirect_to @send, notice: "We’re emailing the delivery link to #{@send.recipient_email}."
    else
      set_library_files
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def destroy
    @send.destroy!
    redirect_to sends_path, notice: "Delivery deleted. Files kept in My Files are unchanged."
  end

  def revoke_access
    @send.revoke_access!
    redirect_to @send, notice: "Recipient access revoked."
  end

  def rotate_access
    @send.update!(email_status: "pending")
    DeliveryEmailJob.perform_later(@send)
    redirect_to @send, notice: "We’re emailing a new delivery link to #{@send.recipient_email}."
  end

  private
    def set_send
      @send = current_user.sends.with_attached_files.includes(:send_events).find(params[:id])
    end

    def send_params
      params.expect(send: [ :recipient_email, :message, files: [] ])
    end

    def save_send
      return @send.save unless managed_hosting?

      current_user.with_lock do
        limit = current_user.monthly_send_limit
        if limit && current_user.sends_this_month >= limit
          @send.errors.add(:base, "Your Free plan includes #{limit} deliveries each month.")
          false
        else
          @send.save.tap { |saved| current_user.record_send! if saved }
        end
      end
    end

    def set_library_files
      files = current_user.files.attachments.includes(:blob).order(created_at: :desc)
      selected_file = files.find_by(id: params[:file_id])
      @library_files = [ selected_file, *files.where.not(id: selected_file&.id).limit(11) ].compact
      @selected_file_id = selected_file&.id
    end
end
