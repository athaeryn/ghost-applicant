class ListPostsTool < MCP::Tool
  tool_name "list_posts"
  title "List Blog Posts"
  description "Lists blog posts. By default only published posts are returned."
  input_schema(
    properties: {
      published: { type: "boolean", description: "Only return published posts (default true). Pass false for drafts too." },
      tag: { type: "string", description: "Filter to posts tagged 'taxonomy:name', e.g. 'topic:rails'" },
      limit: { type: "integer", description: "Maximum number of posts (default 25)" }
    },
    required: []
  )

  def self.call(published: nil, tag: nil, limit: nil, server_context: nil)
    posts = Post.all
    posts = posts.published if published != false
    posts = McpSupport.with_tag(posts, tag) if tag.present?
    posts = posts.recent.limit(limit || 25)
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(posts.map { |p| McpSupport.post(p) }) } ])
  end
end

class CreatePostTool < MCP::Tool
  tool_name "create_post"
  title "Create Blog Post"
  description "Creates a blog post. Body is Markdown. Optionally publish it immediately and attach tags as 'taxonomy:name' strings."
  input_schema(
    properties: {
      title: { type: "string", description: "Post title" },
      body: { type: "string", description: "Post body in Markdown" },
      summary: { type: "string", description: "One-line summary/excerpt" },
      published: { type: "boolean", description: "Publish immediately (default false)" },
      tags: { type: "array", items: { type: "string" }, description: "List of 'taxonomy:name' labels" }
    },
    required: %w[title body]
  )

  def self.call(title:, body:, summary: nil, published: false, tags: nil, server_context: nil)
    post = Post.create!(title: title, body: body, summary: summary, published_at: published ? Time.current : nil)
    post.add_tags(tags) if tags.present?
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.post(post)) } ])
  rescue ActiveRecord::RecordInvalid => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.record.errors.full_messages.join("; ")}" } ])
  end
end

class UpdatePostTool < MCP::Tool
  tool_name "update_post"
  title "Update Blog Post"
  description "Updates an existing post by id or slug. Only provided fields are changed."
  input_schema(
    properties: {
      id: { type: "string", description: "Post id or slug" },
      title: { type: "string", description: "New title" },
      body: { type: "string", description: "New Markdown body" },
      summary: { type: "string", description: "New summary" },
      published: { type: "boolean", description: "Set publish state; true publishes now if not yet published" },
      tags: { type: "array", items: { type: "string" }, description: "Replace all tags with this list of 'taxonomy:name' labels" }
    },
    required: [ "id" ]
  )

  def self.call(id:, title: nil, body: nil, summary: nil, published: nil, tags: nil, server_context: nil)
    post = McpSupport.find_record(Post.all, id)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: post not found" } ]) unless post

    post.title = title if title.present?
    post.body = body if body.present?
    if summary
      post.summary = summary
    end
    post.published_at = Time.current if published == true && post.published_at.blank?
    post.published_at = nil if published == false
    post.save!
    post.replace_tags(tags) if tags
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.post(post)) } ])
  rescue ActiveRecord::RecordInvalid => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.record.errors.full_messages.join("; ")}" } ])
  end
end

class DeletePostTool < MCP::Tool
  tool_name "delete_post"
  title "Delete Blog Post"
  description "Permanently deletes a post by id or slug."
  input_schema(
    properties: { id: { type: "string", description: "Post id or slug" } },
    required: [ "id" ]
  )

  def self.call(id:, server_context: nil)
    post = McpSupport.find_record(Post.all, id)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: post not found" } ]) unless post

    post.destroy!
    MCP::Tool::Response.new([ { type: "text", text: "Deleted post '#{post.title}' (#{post.id})" } ])
  end
end

class PublishPostTool < MCP::Tool
  tool_name "publish_post"
  title "Publish Blog Post"
  description "Publishes (or unpublishes) a post by id or slug."
  input_schema(
    properties: {
      id: { type: "string", description: "Post id or slug" },
      published: { type: "boolean", description: "Whether the post should be published" }
    },
    required: %w[id published]
  )

  def self.call(id:, published:, server_context: nil)
    post = McpSupport.find_record(Post.all, id)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: post not found" } ]) unless post

    post.update!(published_at: published ? (post.published_at || Time.current) : nil)
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.post(post)) } ])
  end
end
