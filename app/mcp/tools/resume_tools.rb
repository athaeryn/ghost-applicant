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

    task = GenerationTask.create!(
      job_application: application,
      kind: 0,
      generation_kind: kind == "cover_letter" ? 1 : 0,
      focus: focus
    )

    if client
      generator = ResumeGenerator.new(client: client)
      selection = begin
        generator.select_records(application, kind: kind)
      rescue StandardError
        { selected: [], notes: "", fallback: true }
      end
      facts, notes = generator.prompt_facts(application, kind: kind, selection: selection)
      prompt = generator.build_application_prompt(application, facts, focus: focus, kind: kind, relevance_notes: notes)
      body = client.chat([ { role: "system", content: generator.system_prompt_for(kind) }, { role: "user", content: prompt } ], temperature: 0.3).to_s
      draft = application.application_drafts.create!(
        kind: kind,
        label: [ client.model.presence, "local" ].compact.first,
        body: body,
        selection: selection
      )
      task.update!(application_draft: draft, model: client.model, selection_json: selection.to_json, succeeded: true, finished_at: Time.current)
    else
      ResumeGenerationJob.perform_now(generation_task_id: task.id)
      task.reload
    end

    if task.succeeded? && task.application_draft
      MCP::Tool::Response.new([ { type: "text", text: "#{kind.titleize} draft saved for '#{application.label}' (draft ##{task.application_draft.id}).\n\n#{task.application_draft.body}" } ])
    else
      MCP::Tool::Response.new([ { type: "text", text: "Error: #{task.error || 'Generation failed'}" } ])
    end
  rescue StandardError => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.message}" } ])
  end
end

class RedraftDraftTool < MCP::Tool
  tool_name "redraft_draft"
  title "Redraft Resume or Cover Letter Draft"
  description "Takes an existing ApplicationDraft and user feedback, then generates a redrafted iteration incorporating the feedback."
  input_schema(
    properties: {
      draft_id: { type: "integer", description: "Id of the parent draft to redraft" },
      general_feedback: { type: "string", description: "General feedback about tone, length, or focus" },
      selection_feedback: { type: "string", description: "Feedback on selections to trigger re-selection" },
      model: { type: "string", description: "Override the LM Studio model name" }
    },
    required: [ "draft_id" ]
  )

  def self.call(draft_id:, general_feedback: nil, selection_feedback: nil, model: nil, client: nil, server_context: nil)
    parent_draft = ApplicationDraft.find_by(id: draft_id.to_i)
    return MCP::Tool::Response.new([ { type: "text", text: "Error: draft not found" } ]) unless parent_draft

    task = GenerationTask.create!(
      job_application: parent_draft.job_application,
      kind: 0,
      generation_kind: parent_draft.kind == "cover_letter" ? 1 : 0,
      parent_draft: parent_draft,
      feedback: general_feedback,
      selection_feedback: selection_feedback
    )

    RedraftGenerationJob.perform_now(generation_task_id: task.id)

    task.reload
    if task.succeeded? && task.application_draft
      MCP::Tool::Response.new([ { type: "text", text: "Redraft saved (draft ##{task.application_draft.id}).\n\n#{task.application_draft.body}" } ])
    else
      MCP::Tool::Response.new([ { type: "text", text: "Error: #{task.error || 'Generation failed'}" } ])
    end
  rescue StandardError => e
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.message}" } ])
  end
end
