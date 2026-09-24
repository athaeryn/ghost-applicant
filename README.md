# Ghost Applicant

Personal portfolio/blog running as a modern Rails app (Rails 8, SQLite, Tailwind)
that **embeds its own Model Context Protocol (MCP) server** at `/mcp`. The whole
site — posts, projects, work history, and a flexible runtime tag system — is
authored over that MCP surface, and resumes can be generated from the facts in
the database by a local LLM running in LM Studio.

## What it does

- **Portfolio/blog site.** Posts, projects, and roles with Markdown bodies,
  rendered with Tailwind.
- **Flexible tag system.** Records are tagged with `taxonomy:name` labels
  (e.g. `skill:ruby`, `tool:rails`, `topic:jobs`). Both *taxonomies* and *tags*
  are created on demand at runtime — no schema changes, no fixed catalog.
- **Embedded MCP server.** A Model Context Protocol server (official Ruby SDK,
  streamable HTTP) mounted at `/mcp` exposes tools to create/list/update/delete
  posts, projects, and roles, manage tags, and generate resumes.
- **Local-LLM resumes.** `generate_resume` calls an LM Studio–compatible
  OpenAI API and writes resume Markdown from the tagged facts in the database.
  Nothing is invented: only facts already in the DB go in.

## Quick start (Docker)

Requires Docker with Compose. LM Studio integration is optional.

```sh
docker compose up -d          # builds and starts the app, binds :3000
docker compose run --rm app bin/rails db:prepare   # first run (already done)
docker compose up -d app      # start, or: docker compose restart app
```

- Site: <http://localhost:3000>
- MCP endpoint: <http://localhost:3000/mcp>
- Health: <http://localhost:3000/up>

Bootstrap some sample content (roles, projects, posts, tags):

```sh
docker compose run --rm app bin/rails db:seed
```

Stop with `docker compose down`. The SQLite database lives in `storage/` on the
host, so your content persists regardless.

### Useful one-liners

```sh
# Run any Rails task inside the app container
docker compose run --rm app bin/rails runner 'Post.count'

# Publish a saved post without the admin UI
docker compose run --rm -T app bin/rails runner \
  'Post.find_by!(title: "…").update!(published_at: Time.current)'

# Restart the app after code/MCP changes
docker compose exec -T app rm -f /app/tmp/pids/server.pid; docker compose restart app
```

A few gotchas worth remembering:

- **Puma/faces one SQLite connection**, so after adding a tool, editing models, or
  writing to `storage/*.sqlite3` from outside, restart the app — an open
  connection in WAL mode won't pick up external file edits until it reconnects.
- Puma is single-process (MCP session state lives in memory). If boot fails with
  "A server is already running", remove a stale `tmp/pids/server.pid`.

## Using the MCP server

Point any MCP client at `http://localhost:3000/mcp`. For example, this repo's
own `opencode.json` already registers it:

```json
{ "mcp": { "ghost-applicant": { "type": "remote", "url": "http://localhost:3000/mcp" } } }
```

(Start the app before opencode — and restart opencode after changing config.)

Exposed tools (22):

| Area      | Tools                                                                                        |
|-----------|----------------------------------------------------------------------------------------------|
| Taxonomies| `list_taxonomies`, `create_taxonomy`                                                         |
| Tags      | `list_tags`, `create_tag`, `tag_record`, `untag_record`, `record_tags`                       |
| Posts     | `list_posts`, `create_post`, `update_post`, `delete_post`, `publish_post`                    |
| Projects  | `list_projects`, `create_project`, `update_project`, `delete_project`                        |
| Roles     | `list_roles`, `create_role`, `update_role`, `delete_role`                                    |
| Resumes   | `generate_resume`, `list_resumes`                                                            |

The server runs a single process (Puma, default). The streamable HTTP transport
keeps session state in memory, which is fine for local single-user use.

## The tag system

Three tables: `Taxonomy → Tag → Tagging` (polymorphic). A label is
`taxonomy:name`. Any tool that accepts `tags:` will create missing taxonomies
and tags automatically. Typical taxonomies: `skill`, `tool`, `topic`,
`industry` — but invent whatever fits; it's a free-form catalog, not a fixed enum.
Tag browsing URLs: `/tags/<taxonomy>` and `/tags/<taxonomy>/<tag>`.

The `meta` taxonomy steers generation: `meta:style-guide` and
`meta:example-*` posts become voice guidance, `meta:context` posts add
background, and the single published `meta:identity` post (a freeform "who
this site is about" bio) is rendered as the `<candidate>` block at the top of
`<source_materials>` so prompts always name who the drafts are for. Keep
exactly one `meta:identity` post.

## Resume generation with LM Studio

`generate_resume` (or the `ResumeGenerator` service) builds a fact sheet from
roles, projects, and per-taxonomy skill tags, then chats with a local model.

Configure via environment (defaults work for a stock LM Studio on the host):

| Variable             | Default                         |
|----------------------|---------------------------------|
| `LM_STUDIO_BASE_URL` | `http://host.docker.internal:1234` |
| `LM_STUDIO_MODEL`    | *unset — auto-detected from `GET /v1/models`* |

Overrides go in a `.env` file next to `docker-compose.yml` (compose reads it
automatically): `LM_STUDIO_MODEL="qwen3-coder-30b-instruct"`. When unset, the
client queries `/v1/models` for the loaded model and labels each saved draft
with it. The tool returns a friendly error if LM Studio is unreachable, so it
degrades cleanly.

The model may be as small as a 4B-parameter tune, so the generator clips
role/project bodies and job descriptions to fit a small context window.

If LM Studio runs on the host, `host.docker.internal` reaches it from the
container (Docker Desktop). Local non-Docker runs fall back to
`http://localhost:1234`.

## Tests & lint

```sh
docker compose run --rm app bin/rails test       # Minitest, builds Tailwind first
docker compose run --rm app bin/rubocop
```

## Layout

```
app/
  assets/tailwind/application.css   # Tailwind v4 input (+ .prose component styles)
  controllers/                      # pages, posts, projects, roles, tags
  mcp/
    mcp_support.rb                  # serializers + shared query helpers
    tools/                          # the 22 MCP tool classes
  models/                           # Post, Project, Role, Taxonomy, Tag, Tagging, GeneratedResume
  models/concerns/taggable.rb       # runtime taxonomy/tag tagging for records
  services/
    lm_studio_client.rb             # OpenAI-compatible client for local models
    resume_generator.rb             # builds the fact sheet + prompts the model
    markdown_renderer.rb            # Commonmark (GFM) → HTML
config/
  initializers/mcp.rb               # assembles MCP_SERVER and its tools
  routes.rb                         # mounts the MCP transport at /mcp
legacy/                             # the previous opencode-only workspace (archived)
bin/dev                             # Rails server + Tailwind watcher, binds 0.0.0.0
```

## Roadmap / natural next steps

- Per-job resume generation: store job descriptions, generate tailored resumes,
  and diff them against the fact base.
- Background resume jobs via Solid Queue (already bundled).
- Simple HTTP auth + a bare-bones browser editor for quick fixes.
- Migrate the archived `legacy/knowledge/` into real `Role`/`Project`/`Post`
  records via the MCP tools.