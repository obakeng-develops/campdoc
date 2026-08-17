class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Campsend <hello@campsend.local>")
  layout "mailer"
end
