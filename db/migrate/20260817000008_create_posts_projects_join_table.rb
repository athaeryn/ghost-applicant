class CreatePostsProjectsJoinTable < ActiveRecord::Migration[8.1]
  def change
    create_join_table :posts, :projects do |t|
      t.index %i[post_id project_id], unique: true
      t.index %i[project_id post_id]
    end
  end
end
