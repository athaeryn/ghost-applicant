class CreateApplicationDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :application_drafts do |t|
      t.references :job_application, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :label
      t.text :body

      t.timestamps
    end
  end
end
