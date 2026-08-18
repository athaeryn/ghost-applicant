# Builds the app's embedded MCP server and exposes it to be mounted at /mcp.
# The StreamableHTTPTransport keeps session state in memory, so run a
# single-process server (Puma default in development).
require "mcp"
require_dependency Rails.root.join("app/services/lm_studio_client").to_s

%w[
  taxonomy_tools
  tag_tools
  post_tools
  project_tools
  role_tools
  job_application_tools
  tagging_tools
  resume_tools
].each do |file|
  require_dependency Rails.root.join("app/mcp/tools/#{file}").to_s
end

MCP_SERVER = MCP::Server.new(
  name: "ghost_portfolio",
  title: "Ghost Applicant Portfolio",
  version: "1.0.0",
  instructions: <<~INSTRUCTIONS,
    This server writes to a personal portfolio/blog backed by Rails.

    - Records are Posts (blog), Projects (portfolio), and Roles (work history).
    - Tags are "taxonomy:name" labels. Taxonomies are free-form categories and are
      created at runtime (e.g. "skill", "topic", "tool", "industry") — invent new
      ones as the catalog grows; both taxonomies and tags are created on demand.
    - Body fields are Markdown.
    - generate_resume calls a local LM Studio endpoint. Only use the facts in the
      database; never invent companies, titles, dates, or outcomes.
  INSTRUCTIONS
  tools: [
    ListTaxonomiesTool, CreateTaxonomyTool,
    ListTagsTool, CreateTagTool,
    ListPostsTool, GetPostTool, CreatePostTool, UpdatePostTool, DeletePostTool, PublishPostTool,
    ListProjectsTool, GetProjectTool, CreateProjectTool, UpdateProjectTool, DeleteProjectTool,
    ListRolesTool, GetRoleTool, CreateRoleTool, UpdateRoleTool, DeleteRoleTool,
    ListJobApplicationsTool, GetJobApplicationTool, CreateJobApplicationTool, UpdateJobApplicationTool, DeleteJobApplicationTool,
    TagRecordTool, UntagRecordTool, RecordTagsTool,
    GenerateResumeTool, ListResumesTool, DraftResumeTool
  ]
)
