# Builds a resume from the fact base (roles, projects, posts and their tags)
# using a local LLM served by LM Studio.
class ResumeGenerator
  def initialize(client: nil)
    @client = client || LmStudioClient.new
  end

  # Returns a persisted GeneratedResume.
  def generate(focus: nil, include_projects: true, include_roles: true)
    facts = build_fact_sheet(include_projects: include_projects, include_roles: include_roles)
    prompt = build_prompt(facts, focus: focus, guidance: writing_guidance)

    content = @client.chat(
      [ { role: "system", content: SYSTEM_PROMPT },
       { role: "user", content: prompt } ],
      temperature: 0.4
    )

    GeneratedResume.create!(
      title: "Resume for #{focus.presence || "general"} — #{Time.current.strftime("%Y-%m-%d %H:%M")}",
      body: content.to_s,
      focus: focus,
      model: @client.model,
      params: JSON.generate({ include_projects: include_projects, include_roles: include_roles })
    )
  end

  # Returns a tailored resume (as text) for a saved job application: the job
  # description is fed to the model alongside the fact base and any writing
  # guidance. Persisting the draft is the caller's job.
  def generate_for_application(application, focus: nil, include_projects: true, include_roles: true)
    facts = build_fact_sheet(include_projects: include_projects, include_roles: include_roles, compact: true)
    prompt = build_application_prompt(application, facts, focus: focus)

    @client.chat(
      [ { role: "system", content: APPLICATION_SYSTEM_PROMPT },
       { role: "user", content: prompt } ],
      temperature: 0.3
    ).to_s
  end

  SYSTEM_PROMPT = <<~PROMPT
    You are a resume writer. You are given a factual summary of a person's
    career (roles, projects, and written work). Produce a clean, focused
    resume in Markdown.

    Ground rules:
    - Use ONLY the facts provided. Never invent companies, titles, dates, or skills.
    - Where a job description is implied by a focus, emphasize the most relevant facts.
    - If important information is missing, say so with a "Note:" line instead of guessing.
    - Keep bullets concise and outcome-oriented, based strictly on the facts.
    - If writing guidance is included, follow it: match that voice and tone exactly.

    Structure: a short summary, then Skills (grouped by the given taxonomies),
    then Work Experience (roles with dates and bullets), then Projects.
  PROMPT

  APPLICATION_SYSTEM_PROMPT = <<~PROMPT
    You are a resume writer tailoring a resume for one specific job posting.
    You are given the job description and a factual summary of the candidate's
    career (roles, projects, and skills).

    Ground rules:
    - Use ONLY the facts provided. Never invent companies, titles, dates, or skills.
    - Read the job description carefully and emphasize the facts that match what
      the posting asks for. Reword, reframe, and select — never fabricate.
    - If a requested qualification has no supporting fact, do not imply it; say
      so in a "Note:" line.
    - Keep bullets concise and outcome-oriented, based strictly on the facts.
    - If writing guidance is included, follow it: match that voice and tone exactly.

    Structure: a short summary, then Skills (grouped by the given taxonomies),
    then Work Experience (roles with dates and bullets), then Projects.
  PROMPT

  # Builds a fact sheet for the generator; also used when composing prompts.
  # compact: true clips role/project bodies to fit small local-model contexts.
  def build_fact_sheet(include_projects:, include_roles:, compact: false)
    sections = []
    sections << "## Roles\n\n" + roles_section(compact: compact) if include_roles
    sections << "## Projects\n\n" + projects_section(compact: compact) if include_projects
    sections << "## Skills (from tags)\n\n" + skills_section
    sections.compact.join("\n")
  end

  # Published posts tagged under the "meta" taxonomy (e.g. meta:style-guide,
  # meta:bio) become writing guidance for the generator.
  def writing_guidance
    meta_posts = Post.published.distinct
      .joins(taggings: { tag: :taxonomy })
      .where(taxonomies: { slug: "meta" })
      .order(:title)

    meta_posts.map do |post|
      labels = post.tag_list.select { |t| t.start_with?("meta:") }.join(", ")
      "### #{post.title} (#{labels})\n\n#{clip(post.body, 500)}"
    end.join("\n\n")
  end

  private

  def clip(text, max_chars)
    text.to_s.truncate(max_chars, omission: "…")
  end

  def roles_section(compact: false)
    Role.chronological.map do |role|
      dates = [ role.start_date, role.end_date ].compact.map(&:iso8601).join(" to ")
      <<~TEXT
        ### #{role.title} at #{role.company} (#{dates})
        #{compact ? clip(role.summary, 250) : role.summary}
        #{compact ? clip(role.body, 600) : role.body}
        Tags: #{role.tag_list.join(", ")}
      TEXT
    end.join("\n")
  end

  def projects_section(compact: false)
    Project.featured.map do |project|
      <<~TEXT
        ### #{project.title} (#{project.status})
        #{compact ? clip(project.summary, 200) : project.summary}
        #{compact ? clip(project.body, 400) : project.body}
        Tags: #{project.tag_list.join(", ")}
      TEXT
    end.join("\n")
  end

  def skills_section
    tags = Tag.includes(:taxonomy).order("taxonomies.name, tags.name").group_by { |t| t.taxonomy.name }
    return "(none)" if tags.empty?

    tags.map { |taxonomy, ts| "- #{taxonomy}: #{ts.map(&:name).join(", ")}" }.join("\n")
  end

  def build_prompt(facts, focus:, guidance: "")
    directive = focus.presence ? "Target role/focus: #{focus}." : "General resume."
    prompt = <<~PROMPT
      #{directive}

      Here is everything currently known:

      #{facts}
    PROMPT
    prompt += "\n\nWriting guidance:\n\n#{guidance}" if guidance.present?
    prompt
  end

  def build_application_prompt(application, facts, focus:)
    directive = focus.presence || application.title.presence || "this posting"
    guidance = writing_guidance
    prompt = <<~PROMPT
      Target role/focus: #{directive}.

      The job posting for this application:

      #{clip(application.description, 1800)}

      Here is everything currently known about the candidate:

      #{facts}
    PROMPT
    prompt += "\n\nWriting guidance:\n\n#{guidance}" if guidance.present?
    prompt
  end
end
