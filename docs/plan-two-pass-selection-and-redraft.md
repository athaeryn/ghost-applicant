# Plan: two-pass relevance selection + feedback redraft

Live model: Gonk at `LM_STUDIO_BASE_URL=http://127.0.0.1:1234`, `openai/gpt-oss-20b` (~120k ctx).
Verified `GET /v1/models` returns that id.

## 1. Goal

Replace the brittle exact tag-intersection prefilter (`skill:ruby` vs
`tool:rails` miss drops a whole role) with a batched LLM relevance selector,
and let the user give feedback on a draft for a grounded redraft.

Explicitly NOT doing per-record agent loop (N+1 calls). One selector call
over compact summaries, then the existing generation call.

## 2. Current pipeline (for reference)

`ResumeGenerator#analyze` (JD -> matched/gap tags, saved on `JobApplication`)
-> `build_tag_intersected_facts` (exact tag overlap) ->
`generate_for_application(kind: resume|cover_letter)` (temp 0.3, strong
zero-fabrication system prompts) -> `ApplicationDraft`.

## 3. Phase A — batched selector (this branch)

`ResumeGenerator#select_records(application, kind:)`:

* Input: full JD (clipped ~8k chars) + compact candidate list, one line per
  record: `type:id | title | company/status | tags | summary~200ch`.
  No full bodies. Small enough for local prefill.
* Output (structured JSON via `response_format: {type: json_schema}`):
  `{ "selected": [{ "type": "role|project|post", "id": 1,
  "relevance": 0|1|2, "reason": "..." }], "notes": "..." }`
  * relevance: 2 = directly maps to JD requirement, 1 = useful context,
    0 = omit (projects/posts only).
  * Roles: selector *ranks*, never omits — all roles always go to pass 2
    (avoids employment gaps; fixes issues-prompt-generation#7).
* `LmStudioClient#chat` gains `response_format:` passthrough + fence
  stripping fallback (gpt-oss emits ```json fences despite instructions).
* On any selector failure (unreachable / bad JSON): fall back to current
  tag-intersect behavior and mark result `fallback: true` so the UI can say so.

`build_selected_facts(application, kind:, selection:)`:

* Roles: all chronological, full bodies, with `relevance="2|1"` +
  `why="..."` attrs from selection (default 1 when fallback).
* Projects/posts: only relevance >= 1 (fallback: tag-intersect set).
* Emits a `<relevance_notes>` block (hints, not facts) alongside
  `<source_materials>`; system prompts get one added line: relevance hints
  guide emphasis only, never license fabrication.

Surfaces:

* `GET /job_applications/:id/preview` shows selector JSON + which ids made
  the cut (reuses `preview_prompt` path).
* MCP: extend `draft_resume` with `use_selection: true` default; add
  `select_records` debug tool. Register in `config/initializers/mcp.rb`,
  add cases to `test/mcp/tools_test.rb` per AGENTS.md.

Tests: selector parsing (valid / fenced / invalid JSON -> fallback),
role-always-included, projects-filtered, preview shows selection.

## 4. Phase B — feedback redraft

`ResumeGenerator#redraft(draft, feedback:)`:

* Rebuilds the *same* selected facts used for the original draft
  (re-run selector or reuse stored selection — v1: re-run, deterministic
  temp 0.1), then prompts: `<job_description> + <source_materials> (same) +
  <previous_draft> + <feedback>` with system addendum: apply ONLY the
  requested changes, keep all factual constraints + gap Notes, no new claims.
* Persists a NEW `ApplicationDraft` (same kind) so history/diff/favorite
  keep working. Migration: `parent_draft_id` (self-ref, nullable) +
  `feedback` (text, nullable) on `application_drafts`.
* Surfaces: `POST /job_applications/:app/drafts/:id/redraft` with textarea
  on `drafts/show`; MCP `redraft_draft(draft_id, feedback)`.

 abre Test: feedback text appears in prompt, new draft links to parent,
factual constraints retained.

## 5. Order of work

1. `response_format` support + fence strip in `LmStudioClient`.
2. Selector prompt/build/parse + unit tests (stub client).
3. `build_selected_facts` + wire into `generate_for_application` /
   `preview_prompt` behind `use_selection` flag; update view.
4. Live smoke vs Gonk: `analyze` + `select` + `draft` on one real posting.
5. Migration + `redraft` service + web + MCP + tests.
6. Docs: update `docs/issues-prompt-generation.md` (§3, §5, §7 resolved).

## 6. Risks

* gpt-oss JSON discipline — mitigate with json_schema + strict fallback.
* Local latency (2 calls/draft) — selector uses temp 0.1 / low reasoning;
  generation stays temp 0.3. No backgrounding in this pass (see
  issues-system-design#1 for follow-up).
* Prompt injection via JD — selector and generator both treat JD as data
  (existing guard); escape `</job_description>`-style delimiters.
