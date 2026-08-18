require "test_helper"

class JobApplicationDraftsControllerTest < ActionDispatch::IntegrationTest
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
end
