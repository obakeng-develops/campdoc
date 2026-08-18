class AddSlugToSends < ActiveRecord::Migration[8.1]
  def change
    add_column :sends, :slug, :string
    add_index :sends, :slug, unique: true
  end
end
