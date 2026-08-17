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

  def self.call(focus: nil, include_projects: nil, include_roles: nil, model: nil, server_context: nil)
    generator = ResumeGenerator.new(client: LmStudioClient.new(model: model))
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
