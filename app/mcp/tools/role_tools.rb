class ListRolesTool < MCP::Tool
  tool_name "list_roles"
  title "List Roles"
  description "Lists work/employment roles in reverse chronological order, optionally filtered by a 'taxonomy:name' tag."
  input_schema(
    properties: {
      tag: { type: "string", description: "Filter to roles tagged 'taxonomy:name'" },
      limit: { type: "integer", description: "Maximum number of roles (default 25)" }
    },
    required: []
  )

  def self.call(tag: nil, limit: nil, server_context: nil)
    roles = Role.all
    roles = McpSupport.with_tag(roles, tag) if tag.present?
    roles = roles.chronological.limit(limit || 25)
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(roles.map { |r| McpSupport.role(r) }) } ])
  end
end

class GetRoleTool < MCP::Tool
  tool_name "get_role"
  title "Get Role"
  description "Returns a single role by id or slug, including its full Markdown body and associations."
  input_schema(
    properties: { id: { type: "string", description: "Role id or slug" } },
    required: [ "id" ]
  )

  def self.call(id:, server_context: nil)
    role = McpSupport.find_record(Role.all, id)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: role not found" } ]) unless role

    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.role_detail(role)) } ])
  end
end

class CreateRoleTool < MCP::Tool
  tool_name "create_role"
  title "Create Role"
  description "Records a past or current role (the fact base for resume generation). Body/summary are Markdown."
  input_schema(
    properties: {
      title: { type: "string", description: "Job title, e.g. 'Staff Software Engineer'" },
      company: { type: "string", description: "Company name" },
      summary: { type: "string", description: "One-line summary of the role" },
      body: { type: "string", description: "Detailed, factual notes about the role (key projects, outcomes)" },
      start_date: { type: "string", description: "Start date as ISO date, e.g. 2020-03-01" },
      end_date: { type: "string", description: "End date as ISO date. Omit for a current role." },
      tags: { type: "array", items: { type: "string" }, description: "List of 'taxonomy:name' labels" }
    },
    required: %w[title company]
  )

  def self.call(title:, company:, summary: nil, body: nil, start_date: nil, end_date: nil, tags: nil, server_context: nil)
    role = Role.create!(
      title: title, company: company, summary: summary, body: body,
      start_date: parse_date(start_date), end_date: parse_date(end_date)
    )
    role.add_tags(tags) if tags.present?
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.role(role)) } ])
  rescue ActiveRecord::RecordInvalid => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.record.errors.full_messages.join("; ")}" } ])
  end

  def self.parse_date(value)
    value.present? ? Date.iso8601(value.to_s) : nil
  rescue ArgumentError, Date::Error
    nil
  end
end

class UpdateRoleTool < MCP::Tool
  tool_name "update_role"
  title "Update Role"
  description "Updates an existing role by id or slug. Only provided fields are changed."
  input_schema(
    properties: {
      id: { type: "string", description: "Role id or slug" },
      title: { type: "string", description: "New job title" },
      company: { type: "string", description: "New company name" },
      summary: { type: "string", description: "New summary" },
      body: { type: "string", description: "New detailed notes" },
      start_date: { type: "string", description: "Start date as ISO date" },
      end_date: { type: "string", description: "End date as ISO date" },
      tags: { type: "array", items: { type: "string" }, description: "Replace all tags with this list of 'taxonomy:name' labels" }
    },
    required: [ "id" ]
  )

  def self.call(id:, title: nil, company: nil, summary: nil, body: nil, start_date: nil, end_date: nil, tags: nil, server_context: nil)
    role = McpSupport.find_record(Role.all, id)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: role not found" } ]) unless role

    attrs = {}
    attrs[:title] = title if title.present?
    attrs[:company] = company if company.present?
    attrs[:summary] = summary if summary
    attrs[:body] = body if body
    attrs[:start_date] = CreateRoleTool.parse_date(start_date) if start_date
    attrs[:end_date] = CreateRoleTool.parse_date(end_date) if end_date
    role.update!(attrs)
    role.replace_tags(tags) if tags
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.role(role)) } ])
  rescue ActiveRecord::RecordInvalid => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.record.errors.full_messages.join("; ")}" } ])
  end
end

class DeleteRoleTool < MCP::Tool
  tool_name "delete_role"
  title "Delete Role"
  description "Permanently deletes a role by id or slug."
  input_schema(
    properties: { id: { type: "string", description: "Role id or slug" } },
    required: [ "id" ]
  )

  def self.call(id:, server_context: nil)
    role = McpSupport.find_record(Role.all, id)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: role not found" } ]) unless role

    role.destroy!
    MCP::Tool::Response.new([ { type: "text", text: "Deleted role '#{role.title} at #{role.company}' (#{role.id})" } ])
  end
end
