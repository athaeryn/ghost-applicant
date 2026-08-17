class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :summary
      t.text :body, null: false
      t.string :url
      t.string :status, null: false, default: "active"
      t.date :started_at
      t.date :ended_at

      t.timestamps
    end

    add_index :projects, :slug, unique: true
    add_index :projects, :started_at
  end
end
