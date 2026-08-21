class AddFavoritedToApplicationDrafts < ActiveRecord::Migration[8.1]
  def change
    add_column :application_drafts, :favorited, :boolean, default: false, null: false
  end
end
