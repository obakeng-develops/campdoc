class Deliveries::AccessesController < ApplicationController
  include DeliveryAccess

  allow_unauthenticated_access
  rate_limit to: 20, within: 1.minute, by: -> { request.remote_ip }

  def create
    delivery = Send.find_by_access_token(params[:public_id], params[:token])
    return head :not_found unless delivery

    grant_delivery_access(delivery)
    redirect_to delivery_path(public_id: delivery.public_id)
  end
end
