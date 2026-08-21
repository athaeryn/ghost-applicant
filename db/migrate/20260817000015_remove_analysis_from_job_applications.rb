class RemoveAnalysisFromJobApplications < ActiveRecord::Migration[8.1]
  def change
    remove_column :job_applications, :analysis, :text
  end
end
