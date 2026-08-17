require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home renders with empty data" do
    get root_path
    assert_response :success
    assert_select "h1"
  end

  test "posts index and show" do
    post = Post.create!(title: "Hi", body: "**world**", published_at: Time.current)
    get posts_path
    assert_response :success

    get post_path(post)
    assert_response :success
    assert_select "h1", "Hi"
    assert_select ".prose"
  end

  test "project and role pages render" do
    project = Project.create!(title: "P", body: "b", status: "active")
    get project_path(project)
    assert_response :success

    role = Role.create!(title: "E", company: "Acme", body: "notes", start_date: Date.new(2020, 1, 1))
    get role_path(role)
    assert_response :success
  end

  test "draft posts are not visible" do
    draft = Post.create!(title: "Secret", body: "b")
    get post_path(draft)
    assert_response :not_found
  end
end
