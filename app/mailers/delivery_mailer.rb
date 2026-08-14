class DeliveryMailer < ApplicationMailer
  def files_ready
    @send = params[:send]
    @access_token = params[:access_token]
    mail to: @send.recipient_email, subject: "#{@send.user.email_address} sent you files"
  end
end
