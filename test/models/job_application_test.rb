require "test_helper"

class JobApplicationTest < ActiveSupport::TestCase
  test "requires a descriptive field" do
    assert_raises(ActiveRecord::RecordInvalid) { JobApplication.create! }
    assert JobApplication.create!(company: "Acme")
    assert JobApplication.create!(description: "We are hiring an engineer.")
  end

  test "defaults to saved status and validates statuses" do
    application = JobApplication.create!(title: "Engineer")
    assert_equal "saved", application.status

    assert_raises(ActiveRecord::RecordInvalid) do
      JobApplication.create!(title: "X", status: "nope")
    end

    %w[saved applied interviewing offer rejected archived].each do |status|
      assert JobApplication.create!(title: "X", status: status)
    end
  end

  test "label combines title and company" do
    assert_equal "Engineer at Acme", JobApplication.new(title: "Engineer", company: "Acme").label
    assert_equal "Engineer", JobApplication.new(title: "Engineer").label
    assert_equal "https://example.com/job", JobApplication.new(url: "https://example.com/job").label
    assert_equal "Untitled application", JobApplication.new.label
  end

  test "is taggable and holds multiple drafts" do
    application = JobApplication.create!(title: "Engineer")
    application.add_tags("stage:new")
    assert_equal [ "stage:new" ], application.tag_list

    application.add_tags("industry:ai")
    application.remove_tag("stage:new")
    assert_equal [ "industry:ai" ], application.reload.tag_list

    application.application_drafts.create!(kind: "cover_letter", label: "claude", body: "Dear team")
    application.application_drafts.create!(kind: "cover_letter", body: "Dear hiring manager")
    assert_equal 2, application.reload.application_drafts.cover_letters.count
  end
end
