class CreateGenerationTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :generation_tasks do |t|
      t.references :job_application, null: false, foreign_key: true
      t.references :application_draft, foreign_key: true
      t.integer :kind, null: false
      t.string :model
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at
      t.boolean :succeeded, default: false, null: false
      t.integer :generation_kind, null: false # 0:resume, 1:cover_letter
      t.text :focus
      t.text :selection_json # serialized selector output
      t.text :feedback # user feedback for redraft
      t.timestamps
    end

    add_index :generation_tasks, :succeeded
    add_index :generation_tasks, :started_at
  end
end
