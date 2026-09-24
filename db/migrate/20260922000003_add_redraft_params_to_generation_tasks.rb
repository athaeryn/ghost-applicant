class AddRedraftParamsToGenerationTasks < ActiveRecord::Migration[8.1]
  def change
    add_reference :generation_tasks, :parent_draft,
                  foreign_key: { to_table: :application_drafts }
    add_column :generation_tasks, :selection_feedback, :text
  end
end
