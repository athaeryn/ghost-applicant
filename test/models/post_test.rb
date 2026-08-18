require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "slugs are generated from the title" do
    post = Post.create!(title: "Hello, World!", body: "body")
    assert_equal "hello-world", post.slug
    assert_equal "hello-world", post.to_param
  end

  test "published scope only returns published posts" do
    published = Post.create!(title: "Published", body: "b", published_at: 1.minute.ago)
    drafted = Post.create!(title: "Draft", body: "b")
    future = Post.create!(title: "Future", body: "b", published_at: 1.day.from_now)

    assert_equal [ published ], Post.published.to_a
    refute drafted.published?
    refute future.published?
  end

  test "requires title and body" do
    assert_raises(ActiveRecord::RecordInvalid) { Post.create!(title: "", body: "b") }
    assert_raises(ActiveRecord::RecordInvalid) { Post.create!(title: "x", body: "") }
  end

  test "links posts to projects and roles" do
    project = Project.create!(title: "A", body: "b")
    role = Role.create!(title: "Engineer", company: "Acme", start_date: Date.new(2020, 1, 1))
    post = Post.create!(title: "Connected", body: "b", projects: [ project ], roles: [ role ])

    assert_equal [ project ], post.projects.to_a
    assert_equal [ role ], post.roles.to_a
    assert_equal [ post ], project.posts.to_a
    assert_equal [ post ], role.posts.to_a

    post.projects.clear
    assert_empty post.reload.projects
  end

  test "project can belong to an optional role" do
    role = Role.create!(title: "Engineer", company: "Acme", start_date: Date.new(2020, 1, 1))
    assigned = Project.create!(title: "Assigned", body: "b", role: role)
    lone = Project.create!(title: "Lone", body: "b")

    assert_equal role, assigned.role
    assert_nil lone.role
    assert_equal [ assigned ], role.projects.to_a

    assigned.update!(role: nil)
    assert_nil assigned.reload.role
    assert_empty role.reload.projects
  end
end
