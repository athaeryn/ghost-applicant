class ListTagsTool < MCP::Tool
  tool_name "list_tags"
  title "List Tags"
  description "Lists tags, optionally filtered to a single taxonomy by slug or name."
  input_schema(
    properties: {
      taxonomy: { type: "string", description: "Optional taxonomy slug or name to filter by, e.g. 'skill'" },
      limit: { type: "integer", description: "Maximum number of tags to return (default 100)" }
    },
    required: []
  )

  def self.call(taxonomy: nil, limit: nil, server_context: nil)
    tags = Tag.ordered
    tags = tags.joins(:taxonomy).where(taxonomies: { slug: taxonomy.to_s.parameterize }) if taxonomy.present?
    tags = tags.limit(limit) if limit
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(tags.map { |t| McpSupport.tag(t) }) } ])
  end
end

class CreateTagTool < MCP::Tool
  tool_name "create_tag"
  title "Create Tag"
  description "Creates a tag inside a taxonomy. If the taxonomy does not exist yet it is created automatically."
  input_schema(
    properties: {
      taxonomy: { type: "string", description: "Taxonomy name or slug, e.g. 'skill' or 'topic'" },
      name: { type: "string", description: "The tag name, e.g. 'Ruby on Rails'" },
      description: { type: "string", description: "Optional description" }
    },
    required: %w[taxonomy name]
  )

  def self.call(taxonomy:, name:, description: nil, server_context: nil)
    tax = Taxonomy.find_or_create_by!(name: taxonomy.strip)
    tag = tax.tags.create!(name: name, description: description)
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.tag(tag)) } ])
  rescue ActiveRecord::RecordInvalid => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.record.errors.full_messages.join("; ")}" } ])
  end
end
