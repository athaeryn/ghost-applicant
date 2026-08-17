# Ghost Applicant

A resume and cover-letter tailoring workspace driven by opencode. You chat with
the model about your real experience; it keeps a fact-based knowledge base and
produces tailored resumes and cover letter drafts for each job opening — in
your own voice, grounded only in what's true.

## How it works

Two parts:

1. **Knowledge base (`knowledge/`)** — a set of markdown files holding who you
   are, your experience, your skills, and your writing voice. This is the only
   place facts come from.
2. **Per-job output (`jobs/`)** — for each opening you apply to, a tailored
   resume and cover letter draft saved into its own folder.

**Ground rule:** nothing is invented. Every resume/letter claim traces to a real
fact in the KB. When information is missing, the model asks you instead of
guessing.

## Layout

```
ghost-applicant/
├── opencode.json                  # opencode config (don't break)
├── AGENTS.md                      # system instructions (the rules)
├── .opencode/
│   ├── skills/resume/SKILL.md     # resume + tailoring workflow
│   ├── skills/ingest/SKILL.md     # ingesting documents + deriving voice
│   ├── commands/kb.md             # /kb — capture your experience
│   └── commands/job.md            # /job — tailor for a specific opening
├── ingest/                        # drop raw docs to convert (see below)
├── scripts/convert-ingest.mjs     # PDF/docx→md converter (MCP fallback)
├── knowledge/                     # your facts and your voice
│   ├── _profile.md                # who you are, target roles, tone
│   ├── skills.md                  # skills & tools
│   ├── letters.md                 # voice patterns distilled from samples
│   ├── roles/                     # one file per past role
│   ├── samples/cover-letters/     # your past letters (voice corpus)
│   └── case-studies/              # your detailed written work
└── jobs/                          # one folder per application
    └── <company>-<role>/
        ├── job-post.md            # the job description
        ├── resume-custom.md       # tailored resume
        ├── cover-letter.md        # cover letter draft
        └── notes.md               # rationale (what you used/cut)
```

## Quick start

0. **Restart opencode** after adding files so commands/skills reload.

1. **Capture your experience — `/kb`**
   ```
   /kb
   ```
   The model interviews you and writes your real history into `knowledge/`.
   Do this for each past role, plus your profile and skills.

2. **Feed it your voice — give the model past letters or a PDF case study**
   Either paste the text, give a file path, or run `/ingest` and point it at
   the files. It converts to markdown under `knowledge/samples/` and
   `knowledge/case-studies/`, then derives your letter voice into
   `knowledge/_profile.md` and `knowledge/letters.md`.

   **If the markitdown MCP tool isn't loaded:** drop the raw files into
   `ingest/`, then run `node scripts/convert-ingest.mjs`. The converted markdown
   appears in `ingest/converted/`, and `/ingest` reads it from there.

3. **Tailor for a job — `/job`**
   ```
   /job https://company.com/careers/senior-engineer
   ```
   It fetches the description, creates `jobs/<company>-<role>/`, and writes a
   tailored resume + cover letter. It will ask you clarifying questions if the
   KB doesn't cover what the job needs.

## The commands

| Command      | What it does                                      |
| ------------ | ------------------------------------------------- |
| `/kb`        | Interview you and record experience into the KB   |
| `/ingest`    | Add past letters / case studies and learn your voice |
| `/job`       | Tailored resume + cover letter for an opening     |

(You can also just chat — the resume and ingest skills auto-trigger from what
you say.)

## Notes

- Output is markdown for now. PDF/.doc rendering is a future option.
- Commit/back up the repo so your KB and voice data are safe — it's plain text.