if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
  service = ENV["ACTIVE_STORAGE_SERVICE"]
  allowed_services = %w[local s3]
  raise "ACTIVE_STORAGE_SERVICE must be local or s3" unless service.in?(allowed_services)

  required = %w[APP_HOST MAIL_FROM SMTP_ADDRESS SMTP_USERNAME SMTP_PASSWORD]
  required += %w[STORAGE_ENDPOINT STORAGE_ACCESS_KEY_ID STORAGE_SECRET_ACCESS_KEY STORAGE_BUCKET] if service == "s3"
  missing = required.select { |name| ENV[name].blank? }
  raise "Missing production configuration: #{missing.join(', ')}" if missing.any?
end
