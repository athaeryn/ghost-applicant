require "test_helper"

class JobApplicationDraftsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @application = JobApplication.create!(title: "Engineer", company: "Acme", description: "Hiring")
    @draft = @application.application_drafts.create!(kind: "resume", label: "test-model", body: "# Tailored\n\nBody text here.")
  end

  test "shows a draft with its body and a back link" do
    get job_application_draft_path(@application, @draft)
    assert_response :success
    assert_select "h1", "Resume draft"
    assert_select "a", /Back to application/
  end

  test "redraft queues a job with feedback stored on the task" do
    assert_enqueued_with(job: RedraftGenerationJob) do
      post redraft_job_application_draft_path(@application, @draft),
           params: { general_feedback: "Shorten it", selection_feedback: "Drop the widget project" }
    end
    assert_redirected_to job_application_path(@application)

    task = GenerationTask.last
    assert_equal @draft, task.parent_draft
    assert_equal "Shorten it", task.feedback
    assert_equal "Drop the widget project", task.selection_feedback
    assert_equal 0, task.generation_kind
  end
end
