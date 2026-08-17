require "test_helper"

class McpToolsTest < ActiveSupport::TestCase
  def tool_text(response)
    response.content.first[:text]
  end

  test "create_taxonomy creates and duplicates are rejected" do
    response = CreateTaxonomyTool.call(name: "industry", description: "Sectors")
    data = JSON.parse(tool_text(response))
    assert_equal "industry", data["name"]
    assert_equal "industry", data["slug"]

    duplicate = CreateTaxonomyTool.call(name: "Industry")
    assert_match(/Error/, tool_text(duplicate))
  end

  test "create_tag creates tags and taxonomies implicitly" do
    response = CreateTagTool.call(taxonomy: "skill", name: "rust")
    data = JSON.parse(tool_text(response))
    assert_equal "rust", data["name"]
    assert_equal "skill", data["taxonomy"]
    assert Taxonomy.find_by(name: "skill")
  end

  test "create_post with tags, then filter and untag" do
    created = CreatePostTool.call(
      title: "First post",
      body: "Hello **world**",
      published: true,
      tags: [ "topic:meta", "skill:writing" ]
    )
    post = JSON.parse(tool_text(created))
    assert post["published"]
    assert_equal %w[skill:writing topic:meta], post["tags"]

    list_all = JSON.parse(tool_text(ListPostsTool.call))
    assert_equal 1, list_all.size

    filtered = JSON.parse(tool_text(ListPostsTool.call(tag: "topic:meta")))
    assert_equal 1, filtered.size

    other = JSON.parse(tool_text(ListPostsTool.call(tag: "topic:nope")))
    assert_empty other

    tags = JSON.parse(tool_text(RecordTagsTool.call(record_type: "post", record_id: post["id"])))
    assert_includes tags, "skill:writing"

    UntagRecordTool.call(record_type: "post", record_id: post["id"], tag: "skill:writing")
    remaining = JSON.parse(tool_text(RecordTagsTool.call(record_type: "post", record_id: post["id"])))
    assert_equal [ "topic:meta" ], remaining
  end

  test "tag_record creates taxonomies and tags at runtime" do
    CreatePostTool.call(title: "T", body: "b")
    response = TagRecordTool.call(record_type: "post", record_id: "t", tags: [ "fresh-taxonomy:sparkly" ])
    assert_equal [ "fresh-taxonomy:sparkly" ], JSON.parse(tool_text(response))
    assert Taxonomy.find_by(name: "fresh-taxonomy")
    assert Tag.find_by(name: "sparkly")
  end

  test "unknown record types and records return friendly errors" do
    assert_match(/record_type/, tool_text(TagRecordTool.call(record_type: "car", record_id: "1", tags: [ "a:b" ])))
    assert_match(/not found/, tool_text(RecordTagsTool.call(record_type: "post", record_id: "missing")))
  end

  test "like projects and roles via MCP" do
    CreateRoleTool.call(title: "Engineer", company: "Acme", start_date: "2020-01-01", tags: [ "skill:ruby" ])
    CreateProjectTool.call(title: "Widget", body: "w", status: "completed", tags: [ "tool:rails" ])

    roles = JSON.parse(tool_text(ListRolesTool.call))
    assert_equal 1, roles.size
    assert_equal "ruby", roles.first["tags"].first.split(":").last

    projects = JSON.parse(tool_text(ListProjectsTool.call(status: "completed")))
    assert_equal 1, projects.size
  end

  test "generate_resume fails gracefully when LM Studio is down" do
    response = GenerateResumeTool.call
    assert_match(/Error/, tool_text(response))
  end
end
