module ApplicationHelper
  def indexable_page?
    managed_hosting? && controller_name == "home" && action_name.in?(%w[show pricing])
  end

  def canonical_url
    action_name == "pricing" ? pricing_url : root_url
  end

  def status_sentence(send_record)
    case send_record.display_status
    when "revoked" then "Access revoked"
    when "expired" then "Delivery expired"
    when "canceled" then "Delivery canceled"
    when "failed" then "Email failed"
    when "scheduled" then "Scheduled for #{send_record.recipient_name}"
    when "sending" then "Emailing #{send_record.recipient_name}"
    when "downloaded" then "#{send_record.recipient_name} downloaded this delivery"
    when "opened" then "#{send_record.recipient_name} opened this delivery"
    else "Sent to #{send_record.recipient_name}"
    end
  end

  def file_kind(blob)
    extension = blob.filename.extension.to_s.upcase
    extension.presence || "FILE"
  end

  def previewable_image?(blob)
    ActiveStorage.web_image_content_types.include?(blob.content_type)
  end
end
