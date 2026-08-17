class TagRecordTool < MCP::Tool
  tool_name "tag_record"
  title "Tag a Record"
  description "Attaches tags to a post, project, or role. Tags are 'taxonomy:name' labels; new taxonomies and tags are created at runtime."
  input_schema(
    properties: {
      record_type: { type: "string", description: "One of: post, project, role" },
      record_id: { type: "string", description: "Record id or slug" },
      tags: { type: "array", items: { type: "string" }, description: "List of 'taxonomy:name' labels to add" }
    },
    required: %w[record_type record_id tags]
  )

  def self.call(record_type:, record_id:, tags:, server_context: nil)
    klass = McpSupport.record_class(record_type)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: record_type must be one of post, project, role" } ]) unless klass

    record = McpSupport.find_record(klass.all, record_id)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: record not found" } ]) unless record

    record.add_tags(tags)
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(record.tag_list) } ])
  end
end

class UntagRecordTool < MCP::Tool
  tool_name "untag_record"
  title "Untag a Record"
  description "Removes a single 'taxonomy:name' tag from a post, project, or role."
  input_schema(
    properties: {
      record_type: { type: "string", description: "One of: post, project, role" },
      record_id: { type: "string", description: "Record id or slug" },
      tag: { type: "string", description: "The 'taxonomy:name' label to remove" }
    },
    required: %w[record_type record_id tag]
  )

  def self.call(record_type:, record_id:, tag:, server_context: nil)
    klass = McpSupport.record_class(record_type)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: record_type must be one of post, project, role" } ]) unless klass

    record = McpSupport.find_record(klass.all, record_id)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: record not found" } ]) unless record

    record.remove_tag(tag)
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(record.tag_list) } ])
  end
end

class RecordTagsTool < MCP::Tool
  tool_name "record_tags"
  title "Get a Record's Tags"
  description "Returns the tag labels attached to a post, project, or role."
  input_schema(
    properties: {
      record_type: { type: "string", description: "One of: post, project, role" },
      record_id: { type: "string", description: "Record id or slug" }
    },
    required: %w[record_type record_id]
  )

  def self.call(record_type:, record_id:, server_context: nil)
    klass = McpSupport.record_class(record_type)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: record_type must be one of post, project, role" } ]) unless klass

    record = McpSupport.find_record(klass.all, record_id)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: record not found" } ]) unless record

    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(record.tag_list) } ])
  end
end
