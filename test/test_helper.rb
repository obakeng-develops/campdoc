ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def create_uploaded_blob(user, content: "hello", filename: "hello.txt", content_type: "text/plain")
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(content),
        filename: filename,
        content_type: content_type
      ).tap { |blob| blob.update!(uploader_id: user.id) }
    end
  end
end
