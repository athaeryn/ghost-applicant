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
end
