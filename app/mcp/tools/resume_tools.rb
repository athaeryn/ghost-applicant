class GenerateResumeTool < MCP::Tool
  tool_name "generate_resume"
  title "Generate Resume"
  description "Generates a resume in Markdown from the fact base (roles + projects + tagged skills) using a local LLM served by LM Studio. Requires the LM Studio API to be reachable (see LM_STUDIO_BASE_URL). Results are saved and also returned."
  input_schema(
    properties: {
      focus: { type: "string", description: "Optional target role or focus to tailor the resume toward, e.g. 'Senior Rails Engineer'" },
      include_projects: { type: "boolean", description: "Include projects in the resume (default true)" },
      include_roles: { type: "boolean", description: "Include work experience (default true)" },
      model: { type: "string", description: "Override the LM Studio model name" }
    },
    required: []
  )

  def self.call(focus: nil, include_projects: nil, include_roles: nil, model: nil, client: nil, server_context: nil)
    generator = ResumeGenerator.new(client: client || LmStudioClient.new(model: model))
    resume = generator.generate(
      focus: focus,
      include_projects: include_projects != false,
      include_roles: include_roles != false
    )
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(McpSupport.resume(resume)) } ])
  rescue LmStudioUnavailableError => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.message}" } ])
  rescue LmStudioError => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.message}" } ])
  end
end

class ListResumesTool < MCP::Tool
  tool_name "list_resumes"
  title "List Generated Resumes"
  description "Lists previously generated resumes."
  input_schema(
    properties: { limit: { type: "integer", description: "Maximum number to return (default 10)" } },
    required: []
  )

  def self.call(limit: nil, server_context: nil)
    resumes = GeneratedResume.order(created_at: :desc).limit(limit || 10)
    MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(resumes.map { |r| McpSupport.resume(r) }) } ])
  end
end

class DraftResumeTool < MCP::Tool
  tool_name "draft_resume"
  title "Draft Tailored Resume or Cover Letter"
  description "Reads a stored job application (its pasted job description), the fact base (roles + projects + tagged skills), and any meta: writing guidance, then asks the local LM Studio model for a resume or cover letter tailored to that posting. The result is saved as an ApplicationDraft on the job application and returned."
  input_schema(
    properties: {
      job_application_id: { type: "integer", description: "Id of the job application to tailor for" },
      kind: { type: "string", description: "resume or cover_letter (default resume)", enum: %w[resume cover_letter] },
      focus: { type: "string", description: "Optional emphasis beyond the job title" },
      include_projects: { type: "boolean", description: "Include projects in the facts (default true)" },
      include_roles: { type: "boolean", description: "Include roles in the facts (default true)" },
      use_selection: { type: "boolean", description: "Run the relevance selector first to rank records against the posting (default true; falls back to tag intersection)" },
      model: { type: "string", description: "Override the LM Studio model name" }
    },
    required: [ "job_application_id" ]
  )

  def self.call(job_application_id:, kind: "resume", focus: nil, include_projects: nil, include_roles: nil, use_selection: nil, model: nil, client: nil, server_context: nil)
    application = JobApplication.find_by(id: job_application_id.to_i)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: job application not found" } ]) unless application
    return MCP::Tool::Response.new([ { type: "text", text: "Error: kind must be resume or cover_letter" } ]) unless ApplicationDraft::KINDS.include?(kind)

    lm = client || LmStudioClient.new(model: model)
    generator = ResumeGenerator.new(client: lm)
    content = generator.generate_for_application(
      application,
      focus: focus,
      include_projects: include_projects != false,
      include_roles: include_roles != false,
      use_selection: use_selection != false,
      kind: kind
    )

    draft = application.application_drafts.create!(
      kind: kind,
      label: [ lm.model.presence, "local" ].compact.first,
      body: content
    )
    MCP::Tool::Response.new([ { type: "text", text: "#{kind.titleize} draft saved for '#{application.label}' (draft ##{draft.id}).\n\n#{content}" } ])
  rescue LmStudioUnavailableError, LmStudioError => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.message}" } ])
  rescue ActiveRecord::RecordInvalid => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.record.errors.full_messages.join("; ")}" } ])
  end
end
