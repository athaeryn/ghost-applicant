---
description: Build or update the resume knowledge base by capturing your real work experience.
---

Build or update the knowledge-base files under `knowledge/` following the
resume skill. Goal: capture a complete, fact-accurate record of the user's
experience that later job-tailoring can draw from.

$ARGUMENTS

Interview the user conversationally. Work through one role/employer at a time.
Ask concise, targeted questions to get real, verifiable specifics:

- Company, title, start/end dates, location.
- Day-to-day responsibilities.
- Concrete accomplishments and real metrics (percentages, counts, impact),
  changing processes, or scope (team size, users, budgets) — only if true.
- Tools, technologies, and methodologies used.
- Positioning: what they think they did their best/most impressive work.

Then write everything into the KB:

- `knowledge/_profile.md` (if missing or to refresh).
- `knowledge/skills.md`.
- `knowledge/roles/<company>-<role>.md` (one per role).

Keep each role file structured per the skill: frontmatter + Summary,
Responsibilities, Key accomplishments, Tools & technologies. Record facts, not
polish — rewording happens at tailoring time.

If the user isn't sure about a detail, note it as uncertain in the file rather
than inventing it, or ask them to confirm. Only save confirmed facts.

## Ingesting past cover letters and case studies

When the user provides past cover letters, a PDF case study, or any other
source document:

1. Convert the document to markdown and store it:
   - Cover letters → `knowledge/samples/cover-letters/<target>-<slug>.md` per
     the README there (verbatim text + the context/angle it was written for).
   - Case studies → `knowledge/case-studies/<slug>.md` (preserve the original
     wording and rhythm).
2. Read all samples and **derive the user's voice** — concrete traits, not vague
   labels (see the resume skill "Learning voice from samples").
3. Write the derived style into `knowledge/_profile.md` ("Voice / letter style")
   and `knowledge/letters.md` (patterns that worked, what to avoid).
4. Confirm with the user what you actually found in their letter.

Never fabricate facts from a source document; only record what is actually in
the user's own material.