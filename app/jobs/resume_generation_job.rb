class ResumeGenerationJob < ActiveJob::Base
  discard_on ActiveJob::DeserializationError
  retry_on LmStudioUnavailableError, wait: 5.seconds
  retry_on LmStudioError, wait: 10.seconds

  def perform(generation_task_id:)
    task = GenerationTask.find(generation_task_id)
    task.update!(started_at: Time.current)
    application = task.job_application
    kind = task.generation_kind == 1 ? "cover_letter" : "resume"

    generator = ResumeGenerator.new
    selection = begin
      generator.select_records(application, kind: kind)
    rescue LmStudioUnavailableError, LmStudioError
      { selected: [], notes: "", fallback: true }
    end

    facts, notes = generator.prompt_facts(
      application, kind: kind, selection: selection,
      include_projects: true, include_roles: true
    )

    prompt = generator.build_application_prompt(
      application, facts, focus: task.focus, kind: kind, relevance_notes: notes
    )

    begin
      body = generator.client.chat(
        [ { role: "system", content: generator.system_prompt_for(kind) },
         { role: "user", content: prompt } ],
        temperature: 0.3
      ).to_s

      draft = application.application_drafts.create!(
        kind: kind,
        label: [ generator.client.model.presence, "local" ].compact.first,
        body: body,
        selection: selection,
        parent_draft_id: nil,
        feedback: ""
      )

      task.update!(
        application_draft: draft,
        model: generator.client.model,
        selection_json: selection.to_json,
        succeeded: true,
        finished_at: Time.current
      )
    rescue StandardError => e
      task.update!(
        error: e.message,
        succeeded: false,
        finished_at: Time.current
      )
      raise
    end
  end
end
