class DeliveriesController < ApplicationController
  include DeliveryAccess

  allow_unauthenticated_access

  def show
    @send = find_delivery
    return render :not_yet_available, status: :not_found if @send.publication_pending?
    return render :unavailable, status: :not_found unless @send.access_active?

    render :access unless delivery_access_granted?(@send)
  end
end
