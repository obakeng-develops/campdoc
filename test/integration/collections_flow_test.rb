require "test_helper"

class CollectionsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "sender@example.com")
    sign_in_as(@user)
  end

  test "sender creates and manages a collection from My Files" do
    file = library_file(@user, filename: "contract.txt")

    assert_difference "Collection.count", 1 do
      post collections_path, params: { collection: { name: "Client files" } }
    end
    collection = Collection.last

    get new_send_path
    assert_select "a.collection-card", text: /Client files/, count: 0

    post collection_files_path(collection), params: { attachment_id: file.id }
    assert_redirected_to collection_path(collection)
    assert_equal %w[contract.txt], collection.reload.blobs.map { |blob| blob.filename.to_s }

    get new_send_path
    assert_select "a.collection-card", text: /Client files/

    patch collection_path(collection), params: { collection: { name: "Final files" } }
    assert_equal "Final files", collection.reload.name

    assert_no_difference "ActiveStorage::Attachment.count" do
      delete file_path(file)
    end
    assert_redirected_to files_path

    delete collection_path(collection)
    assert collection.reload.removed_at?
    assert_empty collection.collection_files
  end

  test "collection ownership is enforced" do
    collection = @user.collections.create!(name: "Mine")
    other_user = User.create!(email_address: "other@example.com")
    other_file = library_file(other_user)

    post collection_files_path(collection), params: { attachment_id: other_file.id }

    assert_response :not_found
    assert_empty collection.collection_files

    delete session_path
    sign_in_as(other_user)
    get collection_path(collection)
    assert_response :not_found
    patch collection_path(collection), params: { collection: { name: "Stolen" } }
    assert_response :not_found
    delete collection_path(collection)
    assert_response :not_found
  end

  test "collection delivery keeps its URL and follows new revisions" do
    first = library_file(@user, filename: "first.txt")
    second = library_file(@user, filename: "second.txt")
    collection = @user.collections.create!(name: "Launch files")
    collection.add_file!(first)

    post sends_path, params: {
      send: { recipient_email: "sam@example.com", collection_id: collection.id }
    }
    delivery = Send.last
    public_id = delivery.public_id
    token = delivery.issue_access_token!
    delivery.record_event!(:sent)

    post collection_files_path(collection), params: { attachment_id: second.id }

    assert_equal public_id, delivery.reload.public_id
    assert_equal 2, delivery.delivery_revisions.count
    assert_equal %w[first.txt second.txt], delivery.files.map { |file| file.filename.to_s }

    post delivery_access_path(public_id:), params: { token: }
    get delivery_path(public_id:)
    assert_select ".delivery-intro", text: /Launch files/
    assert_select ".delivery-file", count: 2

    post send_revisions_path(delivery), params: {
      revision: { attachment_id: delivery.files.first.id, file: second.blob.signed_id }
    }
    assert_redirected_to send_path(delivery)
    assert_equal 2, delivery.delivery_revisions.count
  end

  private
    def library_file(user, filename: "file.txt")
      blob = create_uploaded_blob(user, filename:)
      user.retain_files([ blob ])
      user.files.attachments.find_by!(blob:)
    end

    def sign_in_as(user)
      login_token, raw_token = LoginToken.issue_for(user)
      post consume_sign_in_path(public_id: login_token.public_id), params: { token: raw_token }
    end
end
