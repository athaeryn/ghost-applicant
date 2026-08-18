class ListProjectsTool < MCP::Tool
  tool_name "list_projects"
  title "List Projects"
  description "Lists portfolio projects, optionally filtered by status ('active', 'completed', 'shelved') or a 'taxonomy:name' tag."
  input_schema(
    properties: {
      status: { type: "string", description: "Filter by status: active, completed, or shelved" },
      tag: { type: "string", description: "Filter to projects tagged 'taxonomy:name'" },
      limit: { type: "integer", description: "Maximum number of projects (default 25)" }
    },
    required: []
  )

  def self.call(status: nil, tag: nil, limit: nil, server_context: nil)
    projects = Project.all
    projects = projects.where(status: status) if status.present?
    projects = McpSupport.with_tag(projects, tag) if tag.present?
    projects = projects.featured.limit(limit || 25)
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(projects.map { |p| McpSupport.project(p) }) } ])
  end
end

class CreateProjectTool < MCP::Tool
  tool_name "create_project"
  title "Create Project"
  description "Creates a portfolio project. Body is Markdown. Status is one of active/completed/shelved (default active). Optionally attach it to the role it was built under."
  input_schema(
    properties: {
      title: { type: "string", description: "Project title" },
      body: { type: "string", description: "Project write-up in Markdown" },
      summary: { type: "string", description: "One-line summary" },
      url: { type: "string", description: "Optional link (repo, live site, write-up)" },
      status: { type: "string", description: "active, completed, or shelved" },
      role: { type: "string", description: "Optional role id or slug this project belongs to" },
      started_at: { type: "string", description: "Start date as ISO date, e.g. 2025-01-15" },
      ended_at: { type: "string", description: "End date as ISO date" },
      tags: { type: "array", items: { type: "string" }, description: "List of 'taxonomy:name' labels" }
    },
    required: %w[title body]
  )

  def self.call(title:, body:, summary: nil, url: nil, status: nil, role: nil, started_at: nil, ended_at: nil, tags: nil, server_context: nil)
    project = Project.create!(
      title: title, body: body, summary: summary, url: url, status: status || "active",
      role: role ? McpSupport.find_record(Role.all, role) : nil,
      started_at: parse_date(started_at), ended_at: parse_date(ended_at)
    )
    project.add_tags(tags) if tags.present?
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.project(project)) } ])
  rescue ActiveRecord::RecordInvalid => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.record.errors.full_messages.join("; ")}" } ])
  end

  def self.parse_date(value)
    value.present? ? Date.iso8601(value.to_s) : nil
  rescue ArgumentError, Date::Error
    nil
  end
end

class UpdateProjectTool < MCP::Tool
  tool_name "update_project"
  title "Update Project"
  description "Updates an existing project by id or slug. Only provided fields are changed; pass role as empty string to clear the association."
  input_schema(
    properties: {
      id: { type: "string", description: "Project id or slug" },
      title: { type: "string", description: "New title" },
      body: { type: "string", description: "New Markdown body" },
      summary: { type: "string", description: "New summary" },
      url: { type: "string", description: "New link" },
      status: { type: "string", description: "active, completed, or shelved" },
      role: { type: "string", description: "Replace the project's role (id or slug); empty string clears it" },
      started_at: { type: "string", description: "Start date as ISO date" },
      ended_at: { type: "string", description: "End date as ISO date" },
      tags: { type: "array", items: { type: "string" }, description: "Replace all tags with this list of 'taxonomy:name' labels" }
    },
    required: [ "id" ]
  )

  def self.call(id:, title: nil, body: nil, summary: nil, url: nil, status: nil, role: nil, started_at: nil, ended_at: nil, tags: nil, server_context: nil)
    project = McpSupport.find_record(Project.all, id)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: project not found" } ]) unless project

    attrs = {}
    attrs[:title] = title if title.present?
    attrs[:body] = body if body.present?
    attrs[:summary] = summary if summary
    attrs[:url] = url if url
    attrs[:status] = status if status.present?
    attrs[:role] = McpSupport.find_record(Role.all, role) if role.present?
    attrs[:role] = nil if role == ""
    attrs[:started_at] = CreateProjectTool.parse_date(started_at) if started_at
    attrs[:ended_at] = CreateProjectTool.parse_date(ended_at) if ended_at
    project.update!(attrs)
    project.replace_tags(tags) if tags
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.project(project)) } ])
  rescue ActiveRecord::RecordInvalid => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.record.errors.full_messages.join("; ")}" } ])
  end
end

class DeleteProjectTool < MCP::Tool
  tool_name "delete_project"
  title "Delete Project"
  description "Permanently deletes a project by id or slug."
  input_schema(
    properties: { id: { type: "string", description: "Project id or slug" } },
    required: [ "id" ]
  )

  def self.call(id:, server_context: nil)
    project = McpSupport.find_record(Project.all, id)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: project not found" } ]) unless project

    project.destroy!
    MCP::Tool::Response.new([ { type: "text", text: "Deleted project '#{project.title}' (#{project.id})" } ])
  end
end
