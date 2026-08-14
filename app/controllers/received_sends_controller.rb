class ReceivedSendsController < ApplicationController
  def index
    @sends = current_user.received_sends.available.with_attached_files.includes(:user).order(created_at: :desc)
  end
end
