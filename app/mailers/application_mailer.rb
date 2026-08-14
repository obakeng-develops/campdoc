class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Campdoc <hello@campdoc.local>")
  layout "mailer"
end
