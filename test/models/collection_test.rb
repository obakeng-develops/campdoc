require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "sender@example.com")
    @collection = @user.collections.create!(name: "Brand assets")
  end

  test "keeps owned files ordered and rejects cross-owner membership in the database" do
    first = library_file(@user, filename: "first.txt")
    second = library_file(@user, filename: "second.txt")

    @collection.add_file!(first)
    @collection.add_file!(second)

    assert_equal %w[first.txt second.txt], @collection.reload.blobs.map { |blob| blob.filename.to_s }

    other_user = User.create!(email_address: "other@example.com")
    other_file = library_file(other_user, filename: "private.txt")
    assert_raises(ActiveRecord::InvalidForeignKey) do
      CollectionFile.create!(collection: @collection, user: @user, blob: other_file.blob, position: 3)
    end
  end

  test "collection changes create immutable delivery revisions" do
    first = library_file(@user, filename: "first.txt")
    second = library_file(@user, filename: "second.txt")
    @collection.add_file!(first)
    delivery = @user.sends.create!(recipient_email: "sam@example.com", collection: @collection, files: @collection.blobs.to_a)

    @collection.add_file!(second)
    @collection.rename!("Final assets")
    @collection.remove_file!(@collection.collection_files.find_by!(blob: first.blob))

    assert_equal [ 1, 2, 3, 4 ], delivery.delivery_revisions.order(:number).pluck(:number)
    assert_equal "Brand assets", delivery.delivery_revisions.first.collection_name
    assert_equal "Final assets", delivery.delivery_revisions.last.collection_name
    assert_equal %w[second.txt], delivery.reload.files.map { |file| file.filename.to_s }

    @collection.remove!
    assert_equal %w[second.txt], delivery.reload.files.map { |file| file.filename.to_s }
  end

  test "a delivered collection cannot become empty" do
    file = library_file(@user)
    @collection.add_file!(file)
    @user.sends.create!(recipient_email: "sam@example.com", collection: @collection, files: @collection.blobs.to_a)

    assert_raises(ActiveRecord::RecordInvalid) do
      @collection.remove_file!(@collection.collection_files.first)
    end
  end

  test "collection files stay within the delivery size limit" do
    @collection.add_file!(library_reservation(@user, Send::MAX_SEND_SIZE))

    error = assert_raises(ActiveRecord::RecordInvalid) do
      @collection.add_file!(library_reservation(@user, 1))
    end
    assert_includes error.record.errors[:base], "Files must total 2 GB or less."
  end

  test "database rejects a delivery backed by another user's collection" do
    other_user = User.create!(email_address: "other@example.com")
    delivery = other_user.sends.new(recipient_email: "sam@example.com")
    delivery.files.attach(create_uploaded_blob(other_user))
    delivery.collection_id = @collection.id

    assert_raises(ActiveRecord::InvalidForeignKey) { delivery.save!(validate: false) }
  end

  private
    def library_file(user, filename: "file.txt")
      blob = create_uploaded_blob(user, filename:)
      user.retain_files([ blob ])
      user.files.attachments.find_by!(blob:)
    end

    def library_reservation(user, byte_size)
      blob = create_uploaded_blob(user, content: "x", filename: "reserved.bin", content_type: "application/octet-stream")
      blob.update_columns(byte_size:)
      user.retain_files([ blob ])
      user.files.attachments.find_by!(blob:)
    end
end
