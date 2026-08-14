module DeliveryAccess
  extend ActiveSupport::Concern

  included do
    before_action :set_private_cache
  end

  private
    def find_delivery
      Send.with_attached_files.find_by!(public_id: params[:public_id])
    end

    def require_delivery_access
      @send = find_delivery
      head :not_found unless @send.access_active? && delivery_access_granted?(@send)
    end

    def grant_delivery_access(delivery)
      session[:delivery_accesses] = (delivery_accesses + [ delivery.public_id ]).uniq.last(10)
    end

    def delivery_accesses
      Array(session[:delivery_accesses])
    end

    def delivery_access_granted?(delivery)
      delivery_accesses.include?(delivery.public_id) || authenticated? && current_user.email_address == delivery.recipient_email
    end

    def set_private_cache
      response.headers["Cache-Control"] = "private, no-store"
    end
end
