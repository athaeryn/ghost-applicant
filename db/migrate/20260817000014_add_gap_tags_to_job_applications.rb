class AddGapTagsToJobApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :job_applications, :gap_tags, :text
  end
end
