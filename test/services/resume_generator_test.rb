require "test_helper"

# A fake LM Studio client that returns canned completions.
class StubLmStudioClient
  attr_reader :model, :last_messages

  def initialize(model: "stub-model")
    @model = model
  end

  def chat(messages, temperature: nil, max_tokens: nil)
    @last_messages = messages
    "## Experience\nSigned, fake resume."
  end
end

class ResumeGeneratorTest < ActiveSupport::TestCase
  setup do
    @client = StubLmStudioClient.new
    @generator = ResumeGenerator.new(client: @client)
  end

  test "generates and persists a resume from tagged facts" do
    taxonomy = Taxonomy.create!(name: "skill")
    taxonomy.tags.create!(name: "ruby")

    role = Role.create!(
      title: "Engineer",
      company: "Acme",
      start_date: Date.new(2020, 1, 1),
      body: "Built things."
    )
    role.add_tags("skill:ruby")
    Project.create!(title: "Widget", body: "A widget.", started_at: Date.new(2021, 1, 1))

    resume = @generator.generate(focus: "Senior Engineer")

    assert resume.persisted?
    assert_equal "Senior Engineer", resume.focus
    assert_equal "stub-model", resume.model
    assert_includes resume.body, "Signed, fake resume."

    user_prompt = @client.last_messages.last[:content]
    assert_includes user_prompt, "Senior Engineer"
    assert_includes user_prompt, "Acme"
    assert_includes user_prompt, "ruby"
  end
end
