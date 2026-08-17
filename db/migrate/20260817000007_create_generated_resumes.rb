class CreateGeneratedResumes < ActiveRecord::Migration[8.1]
  def change
    create_table :generated_resumes do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.string :focus
      t.string :model
      t.text :params

      t.timestamps
    end
  end
end
