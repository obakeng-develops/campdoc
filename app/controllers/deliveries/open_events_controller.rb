class Deliveries::OpenEventsController < ApplicationController
  include DeliveryAccess

  allow_unauthenticated_access
  before_action :require_delivery_access
  rate_limit to: 30, within: 1.minute, by: -> { request.remote_ip }

  def create
    @send.record_event!(:opened)
    head :no_content
  end
end
