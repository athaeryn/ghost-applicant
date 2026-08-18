require "test_helper"

class Admin::PostsControllerTest < ActionDispatch::IntegrationTest
  test "index, new, and edit render" do
    post = Post.create!(title: "Hi", body: "b", published_at: Time.current)
    get admin_posts_path
    assert_response :success
    get new_admin_post_path
    assert_response :success
    get edit_admin_post_path(post)
    assert_response :success
  end

  test "creates a post as a draft with tags" do
    assert_difference "Post.count", 1 do
      post admin_posts_path, params: {
        post: { title: "New", summary: "s", body: "body" },
        "post[tags_input]" => "topic:meta\nskill:writing"
      }
    end
    assert_redirected_to admin_posts_path

    created = Post.find_by(title: "New")
    assert_not created.published?
    assert_equal %w[skill:writing topic:meta], created.tag_list
  end

  test "publishing toggle works and update replaces tags" do
    post = Post.create!(title: "Draft", body: "b")
    patch admin_post_path(post), params: {
      post: { title: "Updated", body: "b2" },
      "post[published]" => "1",
      "post[tags_input]" => "tool:rails"
    }
    assert_redirected_to admin_posts_path

    post.reload
    assert post.published?
    assert_equal "Updated", post.title
    assert_equal [ "tool:rails" ], post.tag_list
  end

  test "associates projects and roles when creating and updating" do
    project = Project.create!(title: "P", body: "b")
    role = Role.create!(title: "Engineer", company: "Acme", start_date: Date.new(2020, 1, 1))

    post admin_posts_path, params: {
      post: { title: "Linked", body: "b", project_ids: [ project.id, "" ], role_ids: [ role.id, "" ] },
      "post[tags_input]" => ""
    }
    created = Post.find_by(title: "Linked")
    assert_equal [ project.id ], created.project_ids
    assert_equal [ role.id ], created.role_ids

    patch admin_post_path(created), params: {
      post: { title: "Linked", body: "b", project_ids: [ "" ], role_ids: [ "" ] },
      "post[tags_input]" => ""
    }
    assert_empty created.reload.project_ids
    assert_empty created.reload.role_ids
  end

  test "deletes a post" do
    post = Post.create!(title: "Bye", body: "b")
    assert_difference "Post.count", -1 do
      delete admin_post_path(post)
    end
    assert_redirected_to admin_posts_path
  end
end
