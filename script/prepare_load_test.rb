require "json"
require "stringio"

abort "Load fixtures are development-only." unless Rails.env.development?
abort "Use local Disk storage for load tests." unless ActiveStorage::Blob.service.is_a?(ActiveStorage::Service::DiskService)
abort "Use file or test mail delivery for load tests." unless ActionMailer::Base.delivery_method.in?(%i[file test])

count = Integer(ENV.fetch("COUNT", 25))
abort "COUNT must be between 1 and 500." unless count.between?(1, 500)

output = Rails.root.join("tmp/locust_users.json")
if output.exist?
  previous = JSON.parse(output.read)
  emails = previous.fetch("users", []).map { |entry| entry.fetch("email") }
  emails << previous["owner_email"] if previous["owner_email"]
  emails.compact.each do |email|
    user = User.find_by(email_address: email)
    next unless user

    user.sends.destroy_all
    user.collections.destroy_all
    user.files.purge
    user.uploaded_blobs.find_each(&:purge)
    user.destroy!
  end
end

run_id = Time.current.strftime("%Y%m%d%H%M%S")
users = count.times.map do |index|
  user = User.create!(email_address: "locust-#{run_id}-#{index}@example.test")
  blob = ActiveStorage::Blob.create_and_upload!(
    io: StringIO.new("Campsend local load fixture #{index}\n"),
    filename: "load-fixture-#{index}.txt",
    content_type: "text/plain"
  )
  blob.update!(uploader_id: user.id)
  user.retain_files([ blob ])
  collection = user.collections.create!(name: "Load collection")
  collection.add_file!(user.files.attachments.find_by!(blob:))
  login_token, raw_token = LoginToken.issue_for(user, intent: "send")

  {
    email: user.email_address,
    login_path: Rails.application.routes.url_helpers.sign_in_path(public_id: login_token.public_id),
    login_token: raw_token,
    blob_signed_id: blob.signed_id,
    collection_path: Rails.application.routes.url_helpers.collection_path(collection)
  }
end

owner = User.create!(email_address: "locust-recipient-fixture-#{run_id}@example.test")
blob = ActiveStorage::Blob.create_and_upload!(
  io: StringIO.new("Published Campsend load fixture\n"),
  filename: "published-load-fixture.txt",
  content_type: "text/plain"
)
blob.update!(uploader_id: owner.id)
delivery = owner.sends.new(recipient_email: "locust-recipient@example.test")
access_token = delivery.issue_access_token
delivery.files.attach(blob)
delivery.save!
delivery.record_event!(:sent)

payload = {
  generated_at: Time.current.iso8601,
  owner_email: owner.email_address,
  users:,
  recipient: {
    delivery_path: Rails.application.routes.url_helpers.delivery_path(public_id: delivery.delivery_identifier),
    access_token:,
    attachment_id: delivery.files.first.id
  }
}
output.write(JSON.pretty_generate(payload))
puts "Prepared #{count} sender(s) in #{output}."
