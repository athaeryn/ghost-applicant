class AddAnalysisToJobApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :job_applications, :analysis, :text
  end
end
