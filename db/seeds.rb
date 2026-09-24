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
post.projects << project unless post.projects.exists?(id: project.id)
post.roles << role unless post.roles.exists?(id: role.id)

style_guide = Post.find_or_initialize_by(slug: "writing-style-guide")
style_guide.update!(
  title: "Writing Style Guide",
  summary: "House style for everything written by the agent: voice, structure, and rules.",
  body: <<~BODY,
    ## Voice

    Write in a candid, understated first person. Sound like a thoughtful
    engineer talking to another engineer, not like marketing copy.

    - Short sentences preferred. One idea per sentence.
    - Plain language over jargon — but use the real technical term when it is the
      honest name for something.
    - Concrete and specific beats broad. A precise detail beats a general claim.
    - Never claim an outcome that is not in the database.
    - Avoid puffery: "robust", "seamless", "passionate", "delve" are banned.
    - Be honest about trade-offs and dead ends. That is where the interesting
      writing lives.

    ## Structure

    - Lead with what it is and why it exists.
    - Then how it works or how the work went, grounded in specifics.
    - Open with a hook; end with something to take away.
    - Markdown: '##' sections, short paragraphs, occasional bullets or code
      examples when they earn their place.

    ## Rules

    - Facts live in the database. Reword, reframe, and select — never invent
      companies, titles, dates, outcomes, or metrics. When something is missing,
      say so with a "Note:" line instead of guessing.
    - Tag every record. Preferred taxonomies: topic, tool, skill. Content about
      the site or the writer goes under meta:.
    - Link each post to the projects and roles it describes, by id or slug.
    - Match the tone of existing posts; consistency beats cleverness.
    - When unsure what is true, check the database before writing.
  BODY
  published_at: Time.current
)
style_guide.replace_tags([ "meta:style-guide" ])

identity = Post.find_or_initialize_by(slug: "identity")
identity.update!(
  title: "Identity",
  summary: "Who this site is about — used as the <candidate> block in generation prompts.",
  body: <<~BODY,
    Example User — replace this with a real bio via the admin posts UI or the
    `update_post` MCP tool. Keep exactly one published post tagged
    `meta:identity`; it tells the resume/cover-letter prompts who the drafts
    are for.
  BODY
  published_at: Time.current
)
identity.replace_tags([ "meta:identity" ])
