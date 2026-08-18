class AddRoleToProjects < ActiveRecord::Migration[8.1]
  def change
    add_reference :projects, :role, null: true, foreign_key: true
  end
end
