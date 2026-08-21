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

  test "analyze parses response with known and unknown tags" do
    # Set up a tag in the catalog — needs a record carrying it
    tax = Taxonomy.create!(name: "tool")
    tax.tags.create!(name: "rails")
    role = Role.create!(title: "Engineer", company: "Acme", start_date: Date.new(2020, 1, 1))
    role.add_tags("tool:rails")

    application = JobApplication.create!(
      title: "Rails Developer",
      company: "Acme",
      description: "We need a Rails developer."
    )

    fake = Object.new
    def fake.model; "test-model"; end
    def fake.chat(*)
      JSON.generate(
        matched_tags: [ "tool:rails" ],
        gap_tags: [ "tool:wp-cli", "skill:ruby" ]
      )
    end

    generator = ResumeGenerator.new(client: fake)
    result = generator.analyze(application)

    # rails is known (in catalog), should be in tags
    assert_equal %w[tool:rails], result[:tags]
    # gap_tags includes both model-suggested and unknown matched tags
    assert_equal [ "tool:wp-cli", "skill:ruby" ], result[:gap_tags]
  end

  test "analyze handles empty tags section" do
    application = JobApplication.create!(
      title: "PM",
      company: "Acme",
      description: "Looking for a PM."
    )

    fake = Object.new
    def fake.model; "test-model"; end
    def fake.chat(*)
      JSON.generate(
        matched_tags: [],
        gap_tags: []
      )
    end

    generator = ResumeGenerator.new(client: fake)
    result = generator.analyze(application)

    assert_empty result[:tags]
    assert_empty result[:gap_tags]
  end

  test "analyze handles invalid JSON gracefully" do
    application = JobApplication.create!(
      title: "Designer",
      company: "Acme",
      description: "We need a designer."
    )

    fake = Object.new
    def fake.model; "test-model"; end
    def fake.chat(*)
      "not json at all"
    end

    generator = ResumeGenerator.new(client: fake)
    result = generator.analyze(application)

    assert_empty result[:tags]
    assert_empty result[:gap_tags]
  end

  test "tag_catalog returns tags with record counts" do
    tax = Taxonomy.create!(name: "tool")
    tag = tax.tags.create!(name: "rails")
    role = Role.create!(title: "Eng", company: "Acme", start_date: Date.new(2020, 1, 1))
    role.add_tags("tool:rails")
    Project.create!(title: "P1", body: "b").tap { |p| p.add_tags("tool:rails") }

    generator = ResumeGenerator.new(client: StubLmStudioClient.new)
    catalog = generator.send(:tag_catalog)

    assert_includes catalog, "tool:rails (2)"
  end

  test "generate_for_application pulls only tag-intersected roles" do
    # Role with tool:rails
    rails_role = Role.create!(title: "Rails Dev", company: "Acme", start_date: Date.new(2020, 1, 1), body: "Built Rails apps.")
    rails_role.add_tags("tool:rails")

    # Role with tool:python only
    python_role = Role.create!(title: "Python Dev", company: "Beta", start_date: Date.new(2021, 1, 1), body: "Built Python apps.")
    python_role.add_tags("tool:python")

    # Application tagged tool:rails
    app = JobApplication.create!(title: "Rails Dev", company: "Acme", description: "Build Rails things.")
    app.add_tags("tool:rails")

    client = StubLmStudioClient.new
    generator = ResumeGenerator.new(client: client)
    generator.generate_for_application(app)

    prompt = client.last_messages.last[:content]
    assert_includes prompt, "Acme"
    refute_includes prompt, "Beta"
  end

  test "generate_for_application falls back to all roles when no tags" do
    rails_role = Role.create!(title: "Rails Dev", company: "Acme", start_date: Date.new(2020, 1, 1), body: "Built Rails apps.")
    rails_role.add_tags("tool:rails")

    app = JobApplication.create!(title: "Rails Dev", company: "Acme", description: "Build Rails things.")
    # No tags on application

    client = StubLmStudioClient.new
    generator = ResumeGenerator.new(client: client)
    generator.generate_for_application(app)

    prompt = client.last_messages.last[:content]
    assert_includes prompt, "Acme"
  end

  test "generate_for_application uses kind-specific meta guidance" do
    Role.create!(title: "Eng", company: "Acme", start_date: Date.new(2020, 1, 1))

    # Create meta posts
    resume_post = Post.create!(title: "Resume Style", body: "Be concise.", published_at: Time.current)
    resume_post.add_tags("meta:example-resume")
    cover_post = Post.create!(title: "Cover Letter Style", body: "Be warm.", published_at: Time.current)
    cover_post.add_tags("meta:example-cover-letter")
    context_post = Post.create!(title: "Context Notes", body: "Be professional.", published_at: Time.current)
    context_post.add_tags("meta:context")

    app = JobApplication.create!(title: "Dev", company: "X", description: "Build things.")

    client = StubLmStudioClient.new
    generator = ResumeGenerator.new(client: client)

    generator.generate_for_application(app, kind: "resume")
    resume_prompt = client.last_messages.last[:content]
    assert_includes resume_prompt, "Be concise"
    refute_includes resume_prompt, "Be warm"

    generator.generate_for_application(app, kind: "cover_letter")
    cover_prompt = client.last_messages.last[:content]
    assert_includes cover_prompt, "Be warm"
    assert_includes cover_prompt, "Be professional"
  end
end
