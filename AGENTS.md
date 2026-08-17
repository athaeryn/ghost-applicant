# Ghost Applicant

This repo is a resume/cover-letter tailoring workspace driven by opencode.

## What it is

A collection of markdown documents that capture your real, verifiable work
experience (the **knowledge base**), plus a per-job workflow that turns a job
description into a tailored resume and cover letter draft. Everything is
grounded in facts from the knowledge base — nothing invented.

## Layout

- `opencode.json` — opencode config (do not break it)
- `.opencode/skills/resume/SKILL.md` — THE workflow rules. Read and follow it.
- `.opencode/skills/ingest/SKILL.md` — ingesting documents and deriving voice
- `.opencode/commands/kb.md` — `/kb` command: build or update the KB
- `.opencode/commands/ingest.md` — `/ingest` command: add docs & learn voice
- `.opencode/commands/job.md` — `/job` command: tailor for a specific opening
- `knowledge/` — the source-of-truth knowledge base (see below)
- `jobs/` — one folder per job opening
- `ingest/` — drop raw documents here (PDFs, docx, etc.); `node
  scripts/convert-ingest.mjs` converts them to markdown in `ingest/converted/`
- `scripts/convert-ingest.mjs` — standalone PDF/docx→markdown converter used
  when the `markitdown` MCP tool isn't loaded in an opencode session

## The knowledge base (`knowledge/`)

Current shape (adjust if the skill instructs otherwise):

- `knowledge/_profile.md` — who you are, target roles, preferences, tone/voice
- `knowledge/skills.md` — technical + soft skills, tools, domain expertise
- `knowledge/letters.md` — voice/letter patterns distilled from your samples
- `knowledge/roles/<company>-<role>.md` — one file per role, structured facts
- `knowledge/samples/cover-letters/<target>.md` — your past cover letters (voice corpus)
- `knowledge/case-studies/<slug>.md` — your detailed written work (facts + style)

## Ground rules

1. **Every resume/letter claim must come from the KB** — reword, reframe, and
   select from real facts. Never fabricate skills, employers, titles, dates, or
   metrics. If something is missing or ambiguous, ask the user to clarify
   before writing it.
2. Prefer asking questions over guessing when the goal is a shippable document.
3. Keep the KB tidy: one role per file, consistent sections. Frontmatter
   (company, role, dates, location) at the top.

## Workflow

- To grow or edit the KB: run `/kb` (or just chat — the resume skill auto-triggers).
- To ingest a past letter or case study and learn your voice: run `/ingest`.
- To tailor for a job: run `/job <url-or-description>`.