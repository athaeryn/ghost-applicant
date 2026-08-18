class ListJobApplicationsTool < MCP::Tool
  tool_name "list_job_applications"
  title "List Job Applications"
  description "Lists tracked job applications, optionally filtered by status ('saved', 'applied', 'interviewing', 'offer', 'rejected', 'archived') or a 'taxonomy:name' tag."
  input_schema(
    properties: {
      status: { type: "string", description: "Filter by status" },
      tag: { type: "string", description: "Filter to applications tagged 'taxonomy:name'" },
      limit: { type: "integer", description: "Maximum number to return (default 25)" }
    },
    required: []
  )

  def self.call(status: nil, tag: nil, limit: nil, server_context: nil)
    applications = JobApplication.all
    applications = applications.where(status: status) if status.present?
    applications = McpSupport.with_tag(applications, tag) if tag.present?
    applications = applications.by_recent.limit(limit || 25)
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(applications.map { |j| McpSupport.job_application(j) }) } ])
  end
end

class GetJobApplicationTool < MCP::Tool
  tool_name "get_job_application"
  title "Get Job Application"
  description "Returns a single job application by id, including the full pasted job description, notes, and any resume/cover-letter drafts."
  input_schema(
    properties: { id: { type: "integer", description: "Job application id" } },
    required: [ "id" ]
  )

  def self.call(id:, server_context: nil)
    application = JobApplication.find_by(id: id.to_i)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: job application not found" } ]) unless application

    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.job_application_detail(application)) } ])
  end
end

class CreateJobApplicationTool < MCP::Tool
  tool_name "create_job_application"
  title "Create Job Application"
  description "Tracks a job application. Paste the job description into description. Status defaults to 'saved'. Optionally add 'taxonomy:name' tags."
  input_schema(
    properties: {
      company: { type: "string", description: "Company name" },
      title: { type: "string", description: "Role title" },
      url: { type: "string", description: "URL of the job posting" },
      description: { type: "string", description: "The job description content, pasted verbatim" },
      notes: { type: "string", description: "Private scratch notes" },
      status: { type: "string", description: "saved, applied, interviewing, offer, rejected, or archived" },
      applied_at: { type: "string", description: "Application date as ISO date" },
      tags: { type: "array", items: { type: "string" }, description: "List of 'taxonomy:name' labels" }
    },
    required: [ "description" ]
  )

  def self.call(company: nil, title: nil, url: nil, description:, notes: nil, status: nil, applied_at: nil, tags: nil, server_context: nil)
    application = JobApplication.create!(
      company: company, title: title, url: url, description: description, notes: notes,
      status: status, applied_at: parse_date(applied_at)
    )
    application.add_tags(tags) if tags.present?
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.job_application(application)) } ])
  rescue ActiveRecord::RecordInvalid => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.record.errors.full_messages.join("; ")}" } ])
  end

  def self.parse_date(value)
    value.present? ? Date.iso8601(value.to_s) : nil
  rescue ArgumentError, Date::Error
    nil
  end
end

class UpdateJobApplicationTool < MCP::Tool
  tool_name "update_job_application"
  title "Update Job Application"
  description "Updates a job application by id. Only provided fields are changed; pass status as empty string to leave unchanged."
  input_schema(
    properties: {
      id: { type: "integer", description: "Job application id" },
      company: { type: "string", description: "New company name; empty string clears it" },
      title: { type: "string", description: "New role title; empty string clears it" },
      url: { type: "string", description: "New job posting URL; empty string clears it" },
      description: { type: "string", description: "New job description" },
      notes: { type: "string", description: "New notes; empty string clears them" },
      status: { type: "string", description: "New status" },
      applied_at: { type: "string", description: "Application date as ISO date; empty string clears it" },
      tags: { type: "array", items: { type: "string" }, description: "Replace all tags with this list of 'taxonomy:name' labels" }
    },
    required: [ "id" ]
  )

  def self.call(id:, company: nil, title: nil, url: nil, description: nil, notes: nil, status: nil, applied_at: nil, tags: nil, server_context: nil)
    application = JobApplication.find_by(id: id.to_i)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: job application not found" } ]) unless application

    attrs = {}
    attrs[:company] = company.presence if company
    attrs[:title] = title.presence if title
    attrs[:url] = url.presence if url
    attrs[:description] = description if description
    attrs[:notes] = notes.presence if notes
    attrs[:status] = status if status.present?
    attrs[:applied_at] = parse_date(applied_at) if applied_at
    application.update!(attrs)
    application.replace_tags(tags) if tags
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.job_application(application)) } ])
  rescue ActiveRecord::RecordInvalid => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.record.errors.full_messages.join("; ")}" } ])
  end

  def self.parse_date(value)
    value.present? ? Date.iso8601(value.to_s) : nil
  rescue ArgumentError, Date::Error
    nil
  end
end

class DeleteJobApplicationTool < MCP::Tool
  tool_name "delete_job_application"
  title "Delete Job Application"
  description "Permanently deletes a job application by id (and its drafts)."
  input_schema(
    properties: { id: { type: "integer", description: "Job application id" } },
    required: [ "id" ]
  )

  def self.call(id:, server_context: nil)
    application = JobApplication.find_by(id: id.to_i)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: job application not found" } ]) unless application

    label = application.label
    application.destroy!
    MCP::Tool::Response.new([ { type: "text", text: "Deleted job application '#{label}' (#{application.id})" } ])
  end
end
