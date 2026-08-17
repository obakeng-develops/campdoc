class DeliveryMailer < ApplicationMailer
  def files_ready
    @send = params[:send]
    @access_token = params[:access_token]
    @file_count = @send.files.count
    files = @file_count == 1 ? "a file" : "#{@file_count} files"
    mail to: @send.recipient_email, subject: "#{@send.user.email_address} sent you #{files}"
  end
end
