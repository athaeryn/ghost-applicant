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

  # Phase 1: Analyze a job application.
  # Returns { tags:, gap_tags: }
  def analyze(application, model: nil)
    catalog = tag_catalog
    current_tags = application.tag_list
    prompt = build_analyze_prompt(application, catalog: catalog, current_tags: current_tags)

    raw = @client.chat(
      [ { role: "system", content: ANALYZE_SYSTEM_PROMPT },
       { role: "user", content: prompt } ],
      temperature: 0.2
    ).to_s

    parse_analysis_response(raw, catalog: catalog)
  end

  ANALYZE_SYSTEM_PROMPT = <<~PROMPT
    You are a job-application tagger. You are given a job description, a
    catalog of available tags (with counts of how many records carry each),
    and the tags already on the application.

    Your job is to identify which tags from the catalog are relevant to the
    job posting, and which tags NOT in the catalog would be useful.

    Output ONLY valid JSON matching this schema:

    {
      "matched_tags": ["tag from catalog"],
      "gap_tags": ["tag not in catalog that would be useful"]
    }

    Rules:
    - matched_tags must use ONLY tags that appear in the provided catalog.
    - gap_tags are tags NOT in the catalog that would be relevant to this
      posting but currently have no supporting records.
    - If no tags match, use empty arrays.
    - Do not wrap the JSON in markdown code fences.
  PROMPT

  # Returns a tailored resume (as text) for a saved job application: the job
  # description is fed to the model alongside the fact base and any writing
  # guidance. Persisting the draft is the caller's job.
  #
  # Phase 2 behavior: when the application has tags, only roles and projects
  # whose tag_list intersects with the application's tags are included.
  # Writing guidance is pulled from meta:context (always) plus kind-specific
  # meta posts.
  def generate_for_application(application, focus: nil, include_projects: true, include_roles: true, kind: "resume")
    facts = build_tag_intersected_facts(application, kind: kind, include_projects: include_projects, include_roles: include_roles)
    prompt = build_application_prompt(application, facts, focus: focus, kind: kind)

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

  # Kind-specific writing guidance: meta:context posts first, then the
  # kind-specific post (meta:example-resume or meta:example-cover-letter).
  def kind_writing_guidance(kind:)
    context_posts = meta_posts_for("meta:context")
    example_tag = kind == "cover_letter" ? "meta:example-cover-letter" : "meta:example-resume"
    example_posts = meta_posts_for(example_tag)

    parts = []
    parts.concat(context_posts)
    parts.concat(example_posts)
    parts.join("\n\n")
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

  def tag_catalog
    records = Post.published + Project.all + Role.all
    counts = Hash.new(0)
    records.each do |record|
      record.tag_list.each { |label| counts[label] += 1 }
    end
    counts.sort_by { |label, _| label }.map { |label, count| "#{label} (#{count})" }
  end

  def build_analyze_prompt(application, catalog:, current_tags:)
    catalog_block = catalog.any? ? catalog.join("\n") : "(no tags in catalog)"
    current_block = current_tags.any? ? current_tags.join(", ") : "(none)"
    <<~PROMPT
      Job description:

      #{clip(application.description, 2500)}

      Available tags (tag — records that carry it):

      #{catalog_block}

      Tags already on this application: #{current_block}

      Analyze the job description. Recommend relevant tags from the catalog.
      Note gaps where the fact base may be thin.
    PROMPT
  end

  def parse_analysis_response(raw, catalog:)
    known_labels = catalog.map { |line| line.split(" (").first }

    data = JSON.parse(raw)
    matched = Array(data["matched_tags"]).map(&:to_s)
    gap_tags = Array(data["gap_tags"]).map(&:to_s)

    known = []
    unknown = []
    matched.each do |tag|
      if known_labels.include?(tag)
        known << tag
      else
        unknown << tag
      end
    end

    { tags: known.uniq, gap_tags: gap_tags + unknown }
  rescue JSON::ParserError
    { tags: [], gap_tags: [] }
  end

  def build_application_prompt(application, facts, focus:, kind: "resume")
    directive = focus.presence || application.title.presence || "this posting"
    guidance = kind_writing_guidance(kind: kind)

    prompt = <<~PROMPT
      Target role/focus: #{directive}.

      The job posting for this application:

      #{application.description}

      Here is everything currently known about the candidate:

      #{facts}
    PROMPT
    prompt += "\n\nWriting guidance:\n\n#{guidance}" if guidance.present?
    prompt
  end

  def build_tag_intersected_facts(application, kind:, include_projects:, include_roles:)
    app_tags = application.tag_list
    sections = []

    if include_roles
      roles = app_tags.any? ? intersected_roles(app_tags) : Role.chronological
      sections << "## Roles\n\n" + roles_section_from(roles, compact: true)
    end

    if include_projects
      projects = app_tags.any? ? intersected_projects(app_tags) : Project.featured
      sections << "## Projects\n\n" + projects_section_from(projects, compact: true)
    end

    sections << "## Skills (from tags)\n\n" + skills_section
    sections.compact.join("\n")
  end

  def intersected_roles(app_tags)
    Role.chronological.select { |r| (r.tag_list & app_tags).any? }
  end

  def intersected_projects(app_tags)
    Project.featured.select { |p| (p.tag_list & app_tags).any? }
  end

  def roles_section_from(roles, compact: false)
    roles.map do |role|
      dates = [ role.start_date, role.end_date ].compact.map(&:iso8601).join(" to ")
      <<~TEXT
        ### #{role.title} at #{role.company} (#{dates})
        #{compact ? clip(role.summary, 250) : role.summary}
        #{compact ? clip(role.body, 600) : role.body}
        Tags: #{role.tag_list.join(", ")}
      TEXT
    end.join("\n")
  end

  def projects_section_from(projects, compact: false)
    projects.map do |project|
      <<~TEXT
        ### #{project.title} (#{project.status})
        #{compact ? clip(project.summary, 200) : project.summary}
        #{compact ? clip(project.body, 400) : project.body}
        Tags: #{project.tag_list.join(", ")}
      TEXT
    end.join("\n")
  end

  def meta_posts_for(label)
    taxonomy_name, _, tag_name = label.partition(":")
    Post.published.distinct
      .joins(taggings: { tag: :taxonomy })
      .where(taxonomies: { slug: taxonomy_name }, tags: { name: tag_name })
      .order(:title)
      .map do |post|
        labels = post.tag_list.select { |t| t.start_with?("meta:") }.join(", ")
        "### #{post.title} (#{labels})\n\n#{clip(post.body, 500)}"
      end
  end
end
