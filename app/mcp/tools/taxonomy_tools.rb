class ListTaxonomiesTool < MCP::Tool
  tool_name "list_taxonomies"
  title "List Taxonomies"
  description "Lists all tag taxonomies (e.g. 'skill', 'topic', 'status'). Taxonomies are flexible: new ones can be created at runtime."

  def self.call(server_context: nil)
    taxonomies = Taxonomy.ordered.map { |t| McpSupport.taxonomy(t) }
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(taxonomies) } ])
  end
end

class CreateTaxonomyTool < MCP::Tool
  tool_name "create_taxonomy"
  title "Create Taxonomy"
  description "Creates a new tag taxonomy. Taxonomies are free-form categorizations — name them whatever fits, e.g. 'skill', 'tool', 'industry', 'project-type'."
  input_schema(
    properties: {
      name: { type: "string", description: "Human-readable taxonomy name, e.g. 'skill'" },
      description: { type: "string", description: "Optional description of what this taxonomy means" }
    },
    required: [ "name" ]
  )

  def self.call(name:, description: nil, server_context: nil)
    taxonomy = Taxonomy.create!(name: name, description: description)
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.taxonomy(taxonomy)) } ])
  rescue ActiveRecord::RecordInvalid => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.record.errors.full_messages.join("; ")}" } ])
  end
end
