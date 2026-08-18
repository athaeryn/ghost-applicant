class CreateJobApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :job_applications do |t|
      t.string :company
      t.string :title
      t.string :url
      t.text :description
      t.text :notes
      t.string :status, default: "saved", null: false
      t.date :applied_at

      t.timestamps
    end
  end
end
