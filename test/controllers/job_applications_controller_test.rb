require "test_helper"

class JobApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @application = JobApplication.create!(title: "Staff Engineer", company: "Acme", description: "Hiring now", url: "https://example.com/job")
  end

  test "index and show render" do
    get job_applications_path
    assert_response :success
    assert_select "a", /Staff Engineer/

    get job_application_path(@application)
    assert_response :success
    assert_select "h1", /Staff Engineer at Acme/
  end

  test "add and remove tags from the show view" do
    get job_application_path(@application)
    assert_response :success

    post add_tag_job_application_path(@application), params: { tag: "industry:ai" }
    assert_redirected_to job_application_path(@application)
    assert_equal [ "industry:ai" ], @application.reload.tag_list

    delete remove_tag_job_application_path(@application), params: { tag: "industry:ai" }
    assert_redirected_to job_application_path(@application)
    assert_empty @application.reload.tag_list
  end
end
