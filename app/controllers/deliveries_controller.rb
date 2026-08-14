class DeliveriesController < ApplicationController
  include DeliveryAccess

  allow_unauthenticated_access

  def show
    @send = find_delivery
    return head :not_found unless @send.access_active?

    render :access unless delivery_access_granted?(@send)
  end
end
