class Deliveries::AccessesController < ApplicationController
  include DeliveryAccess

  allow_unauthenticated_access
  rate_limit to: 20, within: 1.minute, by: -> { request.remote_ip }

  def create
    delivery = find_delivery
    return head :not_found unless delivery.access_token_valid?(params[:token])

    grant_delivery_access(delivery)
    redirect_to delivery_path(public_id: delivery.delivery_identifier)
  end
end
