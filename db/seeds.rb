# Sample/lab data so the site, tag system, and MCP server have something to chew
# on. This is sandbox content — replace it with real facts via the MCP tools.
# Reset anytime with: bin/rails db:reset

taxonomies = {
  "skill" => "Technical skills demonstrated in work.",
  "topic" => "Subject matter of posts and projects.",
  "tool" => "Specific tools and technologies used."
}

taxonomies.each do |name, description|
  Taxonomy.find_or_create_by!(name: name) { |t| t.description = description }
end

skill = Taxonomy.find_by(name: "skill")
tool = Taxonomy.find_by(name: "tool")
topic = Taxonomy.find_by(name: "topic")

[ [ "ruby", skill ], [ "ruby-on-rails", tool ], [ "git", tool ], [ "mcp", tool ], [ "jobs", topic ], [ "ai", topic ] ].each do |name, taxonomy|
  taxonomy.tags.find_or_create_by!(name: name)
end

role = Role.find_or_initialize_by(slug: "example-staff-engineer")
role.update!(
  title: "Staff Software Engineer",
  company: "Example Corp",
  summary: "Example role — replace this with a real one.",
  body: <<~BODY,
    This is a placeholder fact-sheet entry. Record real roles with the
    `create_role` MCP tool so resumes are grounded in facts.
  BODY
  start_date: Date.new(2022, 3, 1)
)
role.replace_tags([ "skill:ruby", "tool:ruby-on-rails", "tool:git" ])

project = Project.find_or_initialize_by(slug: "ghost-applicant")
project.update!(
  title: "Ghost Applicant",
  summary: "A Rails portfolio/blog with an embedded MCP server and local-LLM resume generation.",
  body: <<~BODY,
    ## What this is

    A bundle of tools for running your career writing:

    - A **portfolio/blog** frontend (Rails 8, Tailwind).
    - A **flexible tag system** (taxonomies + tags created at runtime).
    - An **embedded MCP server** at `/mcp` so an AI assistant can author
      everything directly against the app.
    - Optional **resume generation** against a local LM Studio model.

    ### Highlight

    Every record can be tagged with free-form *taxonomy:name* labels, and both the
    taxonomy and the tag are created on demand. That keeps the model useful without
    a fixed schema.
  BODY
  status: "active",
  started_at: Date.new(2026, 8, 1),
  url: "https://github.com/example/ghost-applicant"
)
project.replace_tags([ "topic:jobs", "skill:ruby", "tool:rails", "tool:mcp", "topic:ai" ])
project.update!(role: role)

post = Post.find_or_initialize_by(slug: "welcome")
post.update!(
  title: "Hello, world",
  summary: "What you're looking at and how it's written.",
  body: <<~BODY,
    This site is a portfolio and blog generated almost entirely from a Rails app
    that speaks Model Context Protocol. An assistant can create posts, projects,
    and roles, and shape the tag system on the fly — then ask the app to write a
    resume from the facts using a local model.

    Crucially, nothing here is invented: resumes are built only from what's in the
    database, which keeps the whole workflow honest.
  BODY
  published_at: Time.current
)
post.replace_tags([ "topic:ai", "tool:mcp", "tool:rails" ])
post.projects << project
post.roles << role
