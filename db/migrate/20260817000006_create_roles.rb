class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :title, null: false
      t.string :company, null: false
      t.string :slug, null: false
      t.text :summary
      t.text :body
      t.date :start_date
      t.date :end_date

      t.timestamps
    end

    add_index :roles, :slug, unique: true
    add_index :roles, %i[company title]
  end
end
