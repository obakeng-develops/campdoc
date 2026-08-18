class CollectionFile < ApplicationRecord
  belongs_to :collection
  belongs_to :user
  belongs_to :blob, class_name: "ActiveStorage::Blob"

  validates :blob_id, uniqueness: { scope: :collection_id }
  validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :collection_id }
end
