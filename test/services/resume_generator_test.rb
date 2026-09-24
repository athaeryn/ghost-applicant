require "test_helper"

# A fake LM Studio client that returns canned completions.
class StubLmStudioClient
  attr_reader :model, :last_messages

  def initialize(model: "stub-model")
    @model = model
  end

  def chat(messages, temperature: nil, max_tokens: nil, response_format: nil)
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

  test "generate_for_application includes the meta:identity post as a candidate block" do
    Role.create!(title: "Eng", company: "Acme", start_date: Date.new(2020, 1, 1))

    identity = Post.create!(title: "Who I Am", body: "Jane Example, a backend engineer.", published_at: Time.current)
    identity.add_tags("meta:identity")

    app = JobApplication.create!(title: "Dev", company: "X", description: "Build things.")

    client = StubLmStudioClient.new
    generator = ResumeGenerator.new(client: client)
    generator.generate_for_application(app, kind: "resume")

    prompt = client.last_messages.last[:content]
    assert_includes prompt, "<candidate id="
    assert_includes prompt, "Jane Example, a backend engineer."
    assert_includes prompt, "for the person described in <candidate>"
    refute_includes prompt, "for Example User"
  end

  test "generate_for_application omits the candidate block when no identity post exists" do
    Role.create!(title: "Eng", company: "Acme", start_date: Date.new(2020, 1, 1))
    app = JobApplication.create!(title: "Dev", company: "X", description: "Build things.")

    client = StubLmStudioClient.new
    generator = ResumeGenerator.new(client: client)
    generator.generate_for_application(app, kind: "resume")

    prompt = client.last_messages.last[:content]
    refute_includes prompt, "<candidate id="
    refute_includes prompt, "</candidate>"
  end

  test "system prompts direct the model to the candidate block" do
    assert_includes @generator.system_prompt_for("resume"), "<candidate>"
    assert_includes @generator.system_prompt_for("cover_letter"), "<candidate>"
  end

  test "writing_guidance excludes the identity post" do
    identity = Post.create!(title: "Who I Am", body: "Jane Example.", published_at: Time.current)
    identity.add_tags("meta:identity")
    style = Post.create!(title: "Style", body: "Be concise.", published_at: Time.current)
    style.add_tags("meta:style-guide")

    guidance = @generator.writing_guidance
    assert_includes guidance, "Be concise."
    refute_includes guidance, "Jane Example."
  end

  test "build_application_prompt frames revision feedback as the most important part" do
    app = JobApplication.create!(title: "Rails Dev", company: "Acme", description: "Build Rails things.")

    prompt = @generator.build_application_prompt(
      app, "[facts]",
      focus: "Senior Engineer", kind: "resume",
      relevance_notes: "selection notes only",
      revision_feedback: "Shorten the summary dramatically.",
      previous_output: "# Original draft body"
    )

    assert_includes prompt, "<revision_request>"
    assert_includes prompt, "<previous_output>\n# Original draft body\n</previous_output>"
    assert_includes prompt, "REVISION INSTRUCTIONS (MOST IMPORTANT"
    assert_includes prompt, "Shorten the summary dramatically."
    assert_includes prompt, "Revise the <previous_output> in <revision_request>"
    # The selection rationale stays a low-priority hint, separate from the revision.
    assert_includes prompt, "<relevance_notes>\nselection notes only\n</relevance_notes>"
  end

  test "build_application_prompt omits revision section by default" do
    app = JobApplication.create!(title: "Rails Dev", company: "Acme", description: "Build Rails things.")

    prompt = @generator.build_application_prompt(app, "[facts]", focus: "Senior", kind: "resume")

    refute_includes prompt, "revision"
    refute_includes prompt, "<previous_output>"
  end

  test "select_records parses relevance scores and notes" do
    role = Role.create!(title: "Rails Dev", company: "Acme", start_date: Date.new(2020, 1, 1), body: "Built Rails apps.")
    role.add_tags("tool:rails")
    app = JobApplication.create!(title: "Rails Dev", company: "Acme", description: "Build Rails things.")

    fake = Object.new
    def fake.model; "test-model"; end
    def fake.chat(messages, temperature: nil, max_tokens: nil, response_format: nil)
      @messages = messages
      JSON.generate(
        selected: [ { type: "role", id: Role.first.id, relevance: 2, reason: "exact match" } ],
        notes: "rails role fits"
      )
    end

    result = ResumeGenerator.new(client: fake).select_records(app)
    refute result[:fallback]
    assert_equal "role", result[:selected].first[:type]
    assert_equal 2, result[:selected].first[:relevance]
    assert_equal "rails role fits", result[:notes]
  end

  test "select_records strips code fences and drops unknown ids" do
    Role.create!(title: "Eng", company: "Acme", start_date: Date.new(2020, 1, 1), body: "b")
    app = JobApplication.create!(title: "Dev", company: "X", description: "Build things.")

    fake = Object.new
    def fake.model; "test-model"; end
    def fake.chat(*, **)
      "```json\n" + JSON.generate(
        selected: [
          { type: "role", id: Role.first.id, relevance: 9, reason: "clamped" },
          { type: "project", id: 999_999, relevance: 2, reason: "ghost" }
        ]
      ) + "\n```"
    end

    result = ResumeGenerator.new(client: fake).select_records(app)
    assert_equal 1, result[:selected].size
    assert_equal 2, result[:selected].first[:relevance]
  end

  test "select_records falls back on invalid JSON" do
    Role.create!(title: "Eng", company: "Acme", start_date: Date.new(2020, 1, 1), body: "b")
    app = JobApplication.create!(title: "Dev", company: "X", description: "Build things.")

    fake = Object.new
    def fake.model; "test-model"; end
    def fake.chat(*, **); "not json at all"; end

    result = ResumeGenerator.new(client: fake).select_records(app)
    assert result[:fallback]
    assert_empty result[:selected]
  end

  test "generate_for_application uses selector over exact tag overlap" do
    # Tag-intersection would drop this role (tool:rails vs skill:ruby), but
    # the selector keeps it on semantic fit.
    rails_role = Role.create!(title: "Rails Dev", company: "Acme", start_date: Date.new(2020, 1, 1), body: "Built Rails apps.")
    rails_role.add_tags("tool:rails")
    python_role = Role.create!(title: "Python Dev", company: "Beta", start_date: Date.new(2021, 1, 1), body: "Built Python apps.")
    python_role.add_tags("tool:python")
    kept = Project.create!(title: "Kept", body: "relevant", started_at: Date.new(2021, 1, 1))
    kept.add_tags("tool:rails")
    dropped = Project.create!(title: "Dropped", body: "unrelated", started_at: Date.new(2021, 1, 1))
    dropped.add_tags("tool:python")

    app = JobApplication.create!(title: "Ruby Dev", company: "Acme", description: "Ruby on Rails role.")
    app.add_tags("skill:ruby")

    calls = []
    fake = Object.new
    fake.define_singleton_method(:model) { "test-model" }
    fake.define_singleton_method(:chat) do |messages, temperature: nil, max_tokens: nil, response_format: nil|
      calls << messages
      if response_format
        JSON.generate(
          selected: [
            { type: "role", id: Role.find_by(company: "Acme").id, relevance: 2, reason: "Rails is Ruby-adjacent" },
            { type: "role", id: Role.find_by(company: "Beta").id, relevance: 1, reason: "context" },
            { type: "project", id: Project.find_by(title: "Kept").id, relevance: 2, reason: "rails" },
            { type: "project", id: Project.find_by(title: "Dropped").id, relevance: 0, reason: "unrelated" }
          ],
          notes: "prefer rails"
        )
      else
        "draft body"
      end
    end

    generator = ResumeGenerator.new(client: fake)
    generator.generate_for_application(app)

    assert_equal 2, calls.size, "expected selector call + generation call"
    generation_prompt = calls.last.last[:content]
    assert_includes generation_prompt, "Acme"
    assert_includes generation_prompt, "Beta", "all roles are always included"
    assert_includes generation_prompt, "Kept"
    refute_includes generation_prompt, "Dropped"
    assert_includes generation_prompt, "prefer rails"
  end

  test "generate_for_application falls back to tag intersection when selector fails" do
    rails_role = Role.create!(title: "Rails Dev", company: "Acme", start_date: Date.new(2020, 1, 1), body: "Built Rails apps.")
    rails_role.add_tags("tool:rails")
    python_role = Role.create!(title: "Python Dev", company: "Beta", start_date: Date.new(2021, 1, 1), body: "Built Python apps.")
    python_role.add_tags("tool:python")

    app = JobApplication.create!(title: "Rails Dev", company: "Acme", description: "Build Rails things.")
    app.add_tags("tool:rails")

    fake = Object.new
    fake.define_singleton_method(:model) { "test-model" }
    fake.define_singleton_method(:chat) do |messages, temperature: nil, max_tokens: nil, response_format: nil|
      response_format ? "garbage" : "draft body"
    end

    generator = ResumeGenerator.new(client: fake)
    assert_equal "draft body", generator.generate_for_application(app)
  end
end
