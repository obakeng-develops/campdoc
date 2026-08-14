module ApplicationHelper
  def status_sentence(send_record)
    case send_record.status
    when "downloaded" then "#{send_record.recipient_name} downloaded this"
    when "opened" then "#{send_record.recipient_name} opened this"
    when nil then "Sending to #{send_record.recipient_name}"
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
