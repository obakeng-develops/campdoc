class DeliveriesController < ApplicationController
  include DeliveryAccess

  allow_unauthenticated_access

  def show
    @send = find_delivery
    return head :not_found unless @send.access_active?

    render :access unless delivery_accesses.include?(@send.public_id)
  end
end
