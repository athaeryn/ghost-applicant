require "test_helper"

class Admin::GenerationTasksControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "index and show render" do
    application = JobApplication.create!(title: "Engineer", company: "Acme", description: "d")
    task = GenerationTask.create!(job_application: application, kind: 0, generation_kind: 0)
    get admin_generation_tasks_path
    assert_response :success
    get admin_generation_task_path(task)
    assert_response :success
    assert_select "button", "Retry"
  end

  test "succeeded tasks do not show a retry button" do
    application = JobApplication.create!(title: "Engineer", company: "Acme", description: "d")
    task = GenerationTask.create!(job_application: application, kind: 0, generation_kind: 0, succeeded: true)
    get admin_generation_task_path(task)
    assert_response :success
    assert_select "button", text: "Retry", count: 0
  end

  test "retry on a failed resume task requeues and clears the error" do
    application = JobApplication.create!(title: "Engineer", company: "Acme", description: "d")
    task = GenerationTask.create!(
      job_application: application, kind: 0, generation_kind: 0,
      error: "LM Studio is not reachable", started_at: Time.current
    )

    assert_enqueued_with(job: ResumeGenerationJob) do
      post retry_admin_generation_task_path(task)
    end
    assert_redirected_to admin_generation_task_path(task)

    task.reload
    assert_nil task.error
    assert_nil task.started_at
    assert_not task.succeeded
  end

  test "retry on a failed redraft task keeps feedback and requeues RedraftGenerationJob" do
    application = JobApplication.create!(title: "Engineer", company: "Acme", description: "d")
    parent = application.application_drafts.create!(kind: "resume", label: "m", body: "b")
    task = GenerationTask.create!(
      job_application: application, kind: 0, generation_kind: 0,
      parent_draft: parent, feedback: "Shorten it", selection_feedback: "Drop the widget project",
      error: "boom"
    )

    assert_enqueued_with(job: RedraftGenerationJob) do
      post retry_admin_generation_task_path(task)
    end
    assert_redirected_to admin_generation_task_path(task)

    task.reload
    assert_equal parent, task.parent_draft
    assert_equal "Shorten it", task.feedback
    assert_equal "Drop the widget project", task.selection_feedback
    assert_nil task.error
  end
end
