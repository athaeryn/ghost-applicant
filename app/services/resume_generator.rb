# Builds a resume from the fact base (roles, projects, posts and their tags)
# using a local LLM served by LM Studio.
class ResumeGenerator
  attr_reader :client

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

  # Returns the system and user prompts that would be sent for a job application,
  # for debugging/preview purposes.
  def preview_prompt(application, kind: "resume")
    facts = build_tag_intersected_facts(application, kind: kind, include_projects: true, include_roles: true)
    system_prompt = kind == "cover_letter" ? GOOGLE_COVER_LETTER_PROMPT : GOOGLE_RESUME_PROMPT
    user_prompt = build_application_prompt(application, facts, focus: nil, kind: kind)
    [ system_prompt, user_prompt ]
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
    system_prompt = kind == "cover_letter" ? COVER_LETTER_SYSTEM_PROMPT : RESUME_SYSTEM_PROMPT

    @client.chat(
      [ { role: "system", content: system_prompt },
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
    - Do NOT use markdown tables. Use bulleted lists instead.
    - Prefer direct quotes from the facts. Only paraphrase to summarize —
      never invent details or imply expertise without supporting records.

    Structure: a short summary, then Skills (grouped by the given taxonomies),
    then Work Experience (roles with dates and bullets), then Projects.
  PROMPT

  GOOGLE_COVER_LETTER_PROMPT = <<~PROMPT
    You are an expert career copywriter. Your sole task is to draft a professional cover letter tailored to a job posting (<job_description>) based strictly on the provided candidate facts (<source_materials>).

    ### 1. Absolute Factual Constraints

    * **ZERO FABRICATION:** Use ONLY the facts provided. Never invent companies, job titles, employment dates, or skills.
    * **ZERO EXTRAPOLATION:** Do not imply expertise or scale without supporting records. Prefer direct quotes or exact figures from the facts over paraphrasing.
    * **THE HONESTY RULE:** If the job description requires a qualification that the candidate lacks, do not invent or imply it. Instead, omit it from the letter and list it at the very bottom in a "Note:" line.

    ### 2. Narrative & Framing Rules

    * **STRATEGIC SELECTION:** Read the job description carefully. Select and weave only the most relevant candidate facts into a compelling, outcome-oriented narrative. Reframe, but never fabricate.
    * **TONE ADAPTATION:** If the user prompt includes explicit "Writing Guidance" (voice, tone, style), you MUST adopt that exact voice and tone for the entire letter.

    ### 3. Structural & Formatting Output

    * **SALUTATION:** Address the letter to the specific hiring name if provided. If no name is given, use exactly "Dear hiring team,".
    * **LAYOUT:** You must follow a standard business layout:
      1. Greeting
      2. Opening paragraph (expressing interest)
      3. 2 to 3 body paragraphs (highlighting relevant, factual experience)
      4. Closing paragraph
    * **NO TABLES:** Do NOT output markdown tables under any circumstances. Use standard bulleted lists if you need to display structured data.
  PROMPT

  GOOGLE_RESUME_PROMPT = <<~PROMPT
    You are an expert resume writer and layout designer. Your sole task is to draft a professional, tailored resume based strictly on the provided candidate facts and target job description.

    ### 1. Absolute Factual Constraints

    * **ZERO FABRICATION:** Use ONLY the facts provided. Never invent companies, job titles, employment dates, metrics, or technical skills.
    * **ZERO INFLATION:** Do not upgrade titles or scale. If the text says "assisted with project," do not write "managed project." Stick exactly to the scope provided.
    * **THE GAP RULE:** If the target job description requires a core skill or technology that the candidate lacks, do not include it in the resume. Instead, list it at the very bottom in a "Notes" section.

    ### 2. Tailoring & Syntax Rules

    * **RELEVANCE FILTERING:** Select and prioritize the candidate achievements and responsibilities that directly map to the keywords and requirements in the target job description.
    * **ACTION-ORIENTED DICTION:** Format all bullet points starting with strong, active professional verbs (e.g., "Developed," "Optimized," "Led").
    * **OUTCOME FOCUS:** Structure bullets to emphasize tangible business outcomes or exact metrics whenever they are available in the facts.

    ### 3. Structural & Formatting Output

    * **LAYOUT SEQUENCE:** You must output the resume in the following exact markdown layout:
      1. Professional Summary (2-3 sentences max)
      2. Core Skills (Categorized bulleted list)
      3. Professional Experience (Chronological, with Company, Title, Dates, and Bullet Points)
      4. Education & Certifications
    * **NO TABLES:** Do NOT output markdown tables under any circumstances. Use bulleted lists for skills and technical tools.
    * **MARKDOWN PURITY:** Use standard Markdown headers (#, ##, ###) and bold text (**) for emphasis. Avoid custom HTML formatting tags inside the output body.
  PROMPT

  RESUME_SYSTEM_PROMPT = <<~PROMPT
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
    - Do NOT use markdown tables. Use bulleted lists instead.
    - Prefer direct quotes from the facts. Only paraphrase to summarize —
      never invent details or imply expertise without supporting records.

    Structure: a short summary, then Skills (grouped by the given taxonomies),
    then Work Experience (roles with dates and bullets), then Projects.
  PROMPT

  COVER_LETTER_SYSTEM_PROMPT = <<~PROMPT
    You are a cover letter writer tailoring a letter for one specific job
    posting. You are given the job description and a factual summary of the
    candidate's career (roles, projects, and skills).

    Ground rules:
    - Use ONLY the facts provided. Never invent companies, titles, dates, or skills.
    - Read the job description carefully and weave the most relevant facts into
      a compelling narrative. Reframe and select — never fabricate.
    - Address the letter to the hiring team (use "Dear hiring team" if no
      specific name is given).
    - If a requested qualification has no supporting fact, do not imply it; say
      so in a "Note:" line.
    - Keep paragraphs focused and outcome-oriented, based strictly on the facts.
    - If writing guidance is included, follow it: match that voice and tone exactly.
    - Do NOT use markdown tables. Use bulleted lists instead.
    - Prefer direct quotes from the facts. Only paraphrase to summarize —
      never invent details or imply expertise without supporting records.

    Structure: a greeting, an opening paragraph expressing interest, 2-3 body
    paragraphs highlighting relevant experience, and a closing paragraph.
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
      BEGIN SECTION — #{role.id}
        ### #{role.title} at #{role.company} (#{dates})
        #{compact ? clip(role.summary, 250) : role.summary}
        #{compact ? clip(role.body, 600) : role.body}

        (Tags: #{role.tag_list.join(", ")})
      END SECTION — #{role.id}
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
    output_type = kind == "cover_letter" ? "cover letter" : "resume"

    meta = if guidance.present?
                 <<~META
                 <meta>
                 #{guidance}
                 </meta>
                 META
               else
                 ""
               end

    prompt = <<~PROMPT
Target role/focus: #{directive}.

<job_description>
#{application.description}
</job_description>

<source_materials>
#{facts}
</source_materials>

#{meta}

### Task Request
Based strictly on the constraints in your system instructions, draft a professional #{output_type} for Example User tailored to the <job_description> using ONLY the facts provided inside <source_materials>.

If the job description requires critical qualifications not found in the source materials, do not invent them; instead, list them in a "Notes" section at the absolute end of your response.
    PROMPT
    # prompt += "\n\nWriting guidance:\n\n#{guidance}" if guidance.present?
    prompt
  end

  def build_tag_intersected_facts(application, kind:, include_projects:, include_roles:)
    app_tags = application.tag_list
    sections = []

    if include_roles
      roles = app_tags.any? ? intersected_roles(app_tags) : Role.chronological
      sections << "\n<roles>\n"
      sections << roles_section_from(roles, compact: false)
      sections << "\n</roles>\n"
    end

    if include_projects
      projects = app_tags.any? ? intersected_projects(app_tags) : Project.featured
      sections << "\n<projects>\n"
      sections << projects_section_from(projects, compact: false)
      sections << "\n</projects>\n"
    end

    # TODO: include posts

    sections << "## Skills (from tags)\n\n" + skills_section
    sections.compact.join("\n")
  end

  def intersected_roles(app_tags)
    Role.chronological.select { |r| (r.tag_list & app_tags).any? }
  end

  def intersected_projects(app_tags)
    Project.featured.select { |p| (p.tag_list & app_tags).any? }
  end

  def build_tags_attr_string(tag_list)
    grouped_tags = tag_list.each_with_object(Hash.new { |h, k| h[k] = [] }) do |tag, hash|
      category, value = tag.split(':', 2)
      hash[category] << value if value
    end

    # Build the attribute string (e.g., skills="api backend" tools="aws docker")
    tags_attr_string = grouped_tags.map { |category, values| "#{category}=\"#{values.join(' ')}\"" }.join(' ')

    tags_attr_string
  end

  def roles_section_from(roles, compact: false)
    roles.map do |role|
      dates = [ role.start_date, role.end_date ].compact.map(&:iso8601).join(" to ")
      tags_attr = build_tags_attr_string(role.tag_list)
      <<~TEXT
        <role id="#{role.id}" title="#{role.title}" #{tags_attr}>
        # #{role.title} at #{role.company}
        #{dates}
        #{compact ? clip(role.summary, 250) : role.summary}

        #{compact ? clip(role.body, 600) : role.body}
        </role>
      TEXT
    end.join("\n")
  end

  def projects_section_from(projects, compact: false)
    projects.map do |project|
      tags_attr = build_tags_attr_string(project.tag_list)

      role = if project.role.present?
               "role=\"#{project.role.id}\""
             else
               ""
             end

      <<~TEXT
        <project id="#{project.id}" title="#{project.title}" #{role} status="#{project.status}" #{tags_attr}>
        # #{project.title}

        #{compact ? clip(project.summary, 200) : project.summary}

        #{compact ? clip(project.body, 400) : project.body}
        </project>
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
        # labels = post.tag_list.select { |t| t.start_with?("meta:") }.join(", ")
        <<~LINES
        <#{tag_name} id="#{post.id}">
        # #{post.title}
        #{post.body}
        </#{tag_name}>
        LINES
      end
  end
end
