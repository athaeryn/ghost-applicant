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

  private

  # Published posts tagged under the "meta" taxonomy (e.g. meta:style-guide,
  # meta:bio) become writing guidance for the generator.
  def writing_guidance
    meta_posts = Post.published.distinct
      .joins(taggings: { tag: :taxonomy })
      .where(taxonomies: { slug: "meta" })
      .order(:title)

    meta_posts.map do |post|
      labels = post.tag_list.select { |t| t.start_with?("meta:") }.join(", ")
      "### #{post.title} (#{labels})\n\n#{post.body}"
    end.join("\n\n")
  end

  def build_fact_sheet(include_projects:, include_roles:)
    sections = []
    sections << "## Roles\n\n" + roles_section if include_roles
    sections << "## Projects\n\n" + projects_section if include_projects
    sections << "## Skills (from tags)\n\n" + skills_section
    sections.compact.join("\n")
  end

  def roles_section
    Role.chronological.map do |role|
      dates = [ role.start_date, role.end_date ].compact.map(&:iso8601).join(" to ")
      <<~TEXT
        ### #{role.title} at #{role.company} (#{dates})
        #{role.summary}
        #{role.body}
        Tags: #{role.tag_list.join(", ")}
      TEXT
    end.join("\n")
  end

  def projects_section
    Project.featured.map do |project|
      <<~TEXT
        ### #{project.title} (#{project.status})
        #{project.summary}
        #{project.body}
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
end
