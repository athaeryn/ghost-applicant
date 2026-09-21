# Known issues & improvement backlog

Captured from a code review on 2026-08-31, before implementing fixes. Split by
area:

- [Prompt generation](issues-prompt-generation.md) — the `ResumeGenerator`
  pipeline: prompts, fact sheets, analyze flow.
- [System design](issues-system-design.md) — architecture, blocking calls,
  auth, duplication, dead models.
- [UX](issues-ux.md) — the job-application web UI.

## Environment context

The local model is currently **gpt-oss-20b with ~120k context** via LM Studio.
Consequences for prioritization:

- Hard context overflow is unlikely, so token *budgeting* is about output
  quality (relevance filtering, needle-in-haystack degradation) and prefill
  latency on local hardware, not survival.
- gpt-oss supports OpenAI-style structured output (`response_format` with a
  JSON schema) through LM Studio — the `analyze` flow should use it instead of
  prose "output only JSON" instructions.
- gpt-oss is a reasoning model; LM Studio exposes reasoning effort. Low effort
  is probably fine for tagging (`analyze`); medium for drafting.
- `max_tokens: 2048` on the client caps *output*, which can truncate a long
  resume regardless of the big context window (worse for a reasoning model if
  reasoning tokens count against the completion budget).

## Suggested priority

1. ~~Preview/generation prompt mismatch~~ — **fixed** (unified on the
   structured prompt set, see prompt-generation doc).
2. Unify the two fact-sheet formats; add relevance/size budgeting.
3. Move generation to Solid Queue + Turbo Streams (stop blocking requests).
4. Structured output for `analyze` + fence stripping.
5. Auth gate for `/job_applications`, `/admin`, and `/mcp`.
6. Small bugs: colon-less tag 500, eager model detection, attribute escaping.
