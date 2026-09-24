require "test_helper"

class RedraftGenerationJobTest < ActiveJob::TestCase
  test "reads feedback and parent draft from the task and saves a new draft" do
    application = JobApplication.create!(title: "Engineer", company: "Acme", description: "We need Rails.")
    parent = application.application_drafts.create!(
      kind: "resume", label: "local", body: "Original.",
      selection: { selected: [], notes: "", fallback: true }
    )
    task = GenerationTask.create!(
      job_application: application, kind: 0, generation_kind: 0,
      parent_draft: parent, feedback: "Shorten it", selection_feedback: ""
    )

    fake_messages = nil
    fake = Object.new
    fake.define_singleton_method(:model) { "test-model" }
    fake.define_singleton_method(:chat) do |messages, **|
      fake_messages = messages
      "## Updated\nA redrafted resume."
    end

    original_new = ResumeGenerator.method(:new)
    ResumeGenerator.define_singleton_method(:new) { |**opts| original_new.call(client: fake) }
    begin
      RedraftGenerationJob.perform_now(generation_task_id: task.id)
    ensure
      ResumeGenerator.define_singleton_method(:new, original_new)
    end

    task.reload
    assert task.succeeded?
    draft = task.application_draft
    assert_equal parent.id, draft.parent_draft_id
    assert_includes draft.body, "Update"
    assert_equal parent.selection, draft.selection
    assert_match(/Shorten it/, draft.feedback)

    prompt = fake_messages.last[:content]
    assert_includes prompt, "<revision_request>"
    assert_includes prompt, "<previous_output>\nOriginal.\n</previous_output>"
    assert_includes prompt, "Shorten it"
    assert_includes prompt, "Revise the <previous_output> in <revision_request>"
  end

  test "re-runs selection when selection feedback is present" do
    application = JobApplication.create!(title: "Engineer", company: "Acme", description: "We need rails and ruby.")
    parent = application.application_drafts.create!(kind: "resume", label: "local", body: "Original.", selection: nil)
    task = GenerationTask.create!(
      job_application: application, kind: 0, generation_kind: 0,
      parent_draft: parent, feedback: "", selection_feedback: "Include the Rails project"
    )

    fake = Object.new
    def fake.model; "test-model"; end
    def fake.chat(messages, **); "## Updated\nBody."; end

    original_new = ResumeGenerator.method(:new)
    ResumeGenerator.define_singleton_method(:new) { |**opts| original_new.call(client: fake) }
    begin
      RedraftGenerationJob.perform_now(generation_task_id: task.id)
    ensure
      ResumeGenerator.define_singleton_method(:new, original_new)
    end

    task.reload
    assert task.succeeded?
    assert_not_nil task.application_draft
    assert_equal parent.id, task.application_draft.parent_draft_id
  end

  test "records the error and marks the task failed when LM Studio is unreachable" do
    application = JobApplication.create!(title: "Engineer", company: "Acme", description: "Hiring")
    parent = application.application_drafts.create!(kind: "resume", label: "local", body: "Original.",
      selection: { selected: [], notes: "", fallback: true })
    task = GenerationTask.create!(
      job_application: application, kind: 0, generation_kind: 0,
      parent_draft: parent, feedback: "Shorten", selection_feedback: ""
    )

    down = Object.new
    def down.model; "test-model"; end
    def down.chat(messages, **); raise LmStudioUnavailableError, "LM Studio is down"; end

    original_new = ResumeGenerator.method(:new)
    ResumeGenerator.define_singleton_method(:new) { |**opts| original_new.call(client: down) }
    begin
      RedraftGenerationJob.perform_now(generation_task_id: task.id)
    ensure
      ResumeGenerator.define_singleton_method(:new, original_new)
    end

    task.reload
    assert_not task.succeeded?
    assert_equal "LM Studio is down", task.error
    assert task.finished_at
  end
end
