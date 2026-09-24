class RedraftGenerationJob < ActiveJob::Base
  discard_on ActiveJob::DeserializationError
  retry_on LmStudioUnavailableError, wait: 5.seconds
  retry_on LmStudioError, wait: 10.seconds

  def perform(generation_task_id:)
    task = GenerationTask.find(generation_task_id)
    task.update!(started_at: Time.current)
    parent_draft = task.parent_draft
    raise "No parent draft recorded for redraft task ##{task.id}" unless parent_draft

    application = parent_draft.job_application
    kind = parent_draft.kind
    general_feedback = task.feedback.to_s
    selection_feedback = task.selection_feedback.to_s

    generator = ResumeGenerator.new

    # If selection_feedback is present, re-run selection. Otherwise reuse parent selection.
    selection = if selection_feedback.present?
      begin
        generator.select_records(application, kind: kind)
      rescue LmStudioUnavailableError, LmStudioError
        parent_draft.selection || { selected: [], notes: "", fallback: true }
      end
    else
      parent_draft.selection || { selected: [], notes: "", fallback: true }
    end

    # Combine general feedback and selection feedback for the prompt. General
    # feedback revises the draft itself; selection feedback asked for different
    # source material, which also means "reshape the draft around these."
    combined_feedback = [
      general_feedback.present? ? "General feedback on the previous draft: #{general_feedback}" : nil,
      selection_feedback.present? ? "Selection changes (re-selection was run — the new <source_materials> reflect this): #{selection_feedback}" : nil
    ].compact.join("\n\n")

    facts, notes = generator.prompt_facts(
      application, kind: kind, selection: selection,
      include_projects: true, include_roles: true
    )

    prompt = generator.build_application_prompt(
      application, facts, focus: nil, kind: kind,
      relevance_notes: notes,
      revision_feedback: combined_feedback,
      previous_output: parent_draft.body
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
        parent_draft_id: parent_draft.id,
        feedback: combined_feedback
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
