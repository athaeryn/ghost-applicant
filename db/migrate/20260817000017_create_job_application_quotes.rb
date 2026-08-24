class CreateJobApplicationQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :job_application_quotes do |t|
      t.references :job_application, null: false, foreign_key: true
      t.references :source, polymorphic: true
      t.text :body, null: false
      t.timestamps
    end
  end
end
