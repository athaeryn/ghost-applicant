# System design issues

## 1. LLM calls block the request cycle

`analyze`, `draft`, and `draft_cover_letter` in
`app/controllers/job_applications_controller.rb` call the model synchronously
with a 120s read timeout (`app/services/lm_studio_client.rb`). Puma runs
single-process (the MCP transport keeps session state in memory), so one slow
generation freezes the entire site — including the MCP endpoint.

**Suggestion:** Solid Queue is already bundled. Move generation into a job,
mark the draft "pending", and push the finished draft to the page with Turbo
Streams. This also unlocks "generate resume + cover letter" in one click, and
retries on `LmStudioUnavailableError`.

## 2. HTTP call in the client constructor

`LmStudioClient.new` resolves `default_model` eagerly via `GET /v1/models`
(`lm_studio_client.rb:15`). Every `ResumeGenerator.new` — including the
`preview` action, which never calls the model — makes a network request with a
5s open timeout. Make model detection lazy (resolve on first `chat`/`model`
access).

## 3. No auth on job applications, admin, or MCP

- `Admin::BaseController` is deliberately unauthenticated ("local hardware
  only"), but `/job_applications` (descriptions, private notes, drafts, gap
  analysis) lives in the *public* routes namespace alongside the portfolio.
  If this app is ever deployed, the job hunt is public.
- `/mcp` exposes unauthenticated destructive tools (delete_post, delete_role,
  …).

**Suggestion:** even for local use, gate `job_applications*`, `admin`, and
`/mcp` behind HTTP basic auth or a `Rails.env.local?` route constraint. Cheap
insurance against accidental exposure.

## 4. Duplicated logic

- `find_or_create_tag`: `app/models/concerns/taggable.rb` and
  `app/mcp/mcp_support.rb` implement it separately.
- `find_record` (id-or-slug lookup): `McpSupport` and
  `Admin::BaseController`.

Consolidate each into one home (probably `Taggable`/model layer and a shared
lookup helper).

## 5. Taxonomy lookup is case-sensitive

`Taxonomy.find_or_create_by!(name: taxonomy_name.strip)` means `Skill:ruby`
vs `skill:ruby` either creates a duplicate taxonomy or crashes on a slug
uniqueness collision. Normalize (downcase/parameterize) before lookup.

## 6. `gap_tags` stored as newline-joined text

Works, but the analyze flow has outgrown it: a JSON column (or a small
association) would allow per-gap affordances — e.g. a "create supporting
record" button per gap tag, or dismissing gaps individually.

## 7. `JobApplicationQuote` is dead

Model + association + `source_label` logic exist, but nothing writes or reads
quotes — no UI, no MCP tool. Either build the quote-extraction feature (pull
supporting quotes from roles/projects into drafts) or delete the model and
table.

## 8. Documentation drift

- README says "Exposed tools (22)"; `config/initializers/mcp.rb` registers 31.
- README's claim that the generator "clips role/project bodies … to fit a
  small context window" is currently false (no call site passes
  `compact: true`) and the model context is now ~120k anyway.
- `legacy/knowledge/` migration into real records (per AGENTS.md) is still
  pending.
