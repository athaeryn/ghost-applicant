class AddRedraftLineageToApplicationDrafts < ActiveRecord::Migration[8.1]
  def change
    add_column :application_drafts, :parent_draft_id, :integer
    add_column :application_drafts, :feedback, :text
    add_column :application_drafts, :selection, :json
    add_index :application_drafts, :parent_draft_id
    add_foreign_key :application_drafts, :application_drafts, column: :parent_draft_id
  end
end
