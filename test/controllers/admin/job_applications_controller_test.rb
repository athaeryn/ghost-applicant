require "test_helper"

class Admin::JobApplicationsControllerTest < ActionDispatch::IntegrationTest
  test "index, new, show, and edit render" do
    application = JobApplication.create!(title: "Engineer", company: "Acme", description: "d")
    get admin_job_applications_path
    assert_response :success
    get new_admin_job_application_path
    assert_response :success
    get admin_job_application_path(application)
    assert_response :success
    get edit_admin_job_application_path(application)
    assert_response :success
  end

  test "creates and updates an application with tags" do
    assert_difference "JobApplication.count", 1 do
      post admin_job_applications_path, params: {
        job_application: { title: "Engineer", company: "Acme", url: "https://example.com/job", description: "Come work with us", status: "applied" },
        "job_application[tags_input]" => "industry:ai\nchannel:linkedin"
      }
    end
    created = JobApplication.find_by(title: "Engineer")
    assert_equal "applied", created.status
    assert_equal %w[channel:linkedin industry:ai], created.tag_list
    assert_redirected_to job_application_path(created)

    patch admin_job_application_path(created), params: {
      job_application: { title: "Staff Engineer", applied_at: "2026-08-01" },
      "job_application[tags_input]" => "stage:interview"
    }
    created.reload
    assert_equal "Staff Engineer", created.title
    assert_equal Date.new(2026, 8, 1), created.applied_at
    assert_equal [ "stage:interview" ], created.tag_list
  end

  test "deletes an application" do
    application = JobApplication.create!(title: "Engineer", company: "Acme")
    assert_difference "JobApplication.count", -1 do
      delete admin_job_application_path(application)
    end
    assert_redirected_to admin_job_applications_path
  end
end
