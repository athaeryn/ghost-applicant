require "test_helper"

class TaggableTest < ActiveSupport::TestCase
  setup do
    @post = Post.create!(title: "Tagged post", body: "body")
  end

  test "add_tags creates taxonomies and tags at runtime" do
    assert_difference [ -> { Taxonomy.count }, -> { Tag.count } ] do
      @post.add_tags("skill:ruby")
    end

    taxonomy = Taxonomy.find_by(name: "skill")
    assert_equal "skill", taxonomy.slug
    tag = taxonomy.tags.find_by(name: "ruby")
    assert_equal "ruby", tag.slug
    assert_equal [ "skill:ruby" ], @post.tag_list
  end

  test "add_tags is idempotent" do
    2.times { @post.add_tags("skill:ruby") }
    assert_equal 1, @post.tags.count
    assert_equal [ "skill:ruby" ], @post.tag_list
  end

  test "replace_tags swaps the whole set" do
    @post.add_tags("skill:ruby", "tool:rails")
    assert_equal %w[skill:ruby tool:rails], @post.tag_list

    @post.replace_tags([ "topic:ai" ])
    assert_equal [ "topic:ai" ], @post.tag_list
  end

  test "remove_tag drops a single label" do
    @post.add_tags("skill:ruby", "tool:rails")
    @post.remove_tag("skill:ruby")
    assert_equal [ "tool:rails" ], @post.tag_list
  end

  test "tag_list is sorted" do
    @post.add_tags("topic:zzz", "topic:aaa", "skill:mcp")
    assert_equal %w[skill:mcp topic:aaa topic:zzz], @post.tag_list
  end

  test "tags are shared across record types" do
    project = Project.create!(title: "P", body: "b")
    project.add_tags("skill:ruby")
    tag = Tag.find_by(name: "ruby")

    @post.add_tags("skill:ruby")

    assert_equal %w[Post Project], tag.taggings.pluck(:taggable_type).uniq.sort
  end
end
