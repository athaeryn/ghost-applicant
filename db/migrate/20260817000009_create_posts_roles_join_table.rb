class CreatePostsRolesJoinTable < ActiveRecord::Migration[8.1]
  def change
    create_join_table :posts, :roles do |t|
      t.index %i[post_id role_id], unique: true
      t.index %i[role_id post_id]
    end
  end
end
