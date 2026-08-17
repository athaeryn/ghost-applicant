---
description: Create a tailored resume and cover-letter draft for a specific job opening.
---

Tailor a resume and draft a cover letter for the job described below, following
the resume skill and grounding everything in `knowledge/`.

$ARGUMENTS

Steps:

1. Get the job description. The input is a URL or a pasted description. If it
   is a URL, fetch it (or use the provided summary). Always record the source
   URL when available.
2. Read the job description and extract required/desired skills, responsibilities,
   and keywords.
3. Review the knowledge base under `knowledge/`.
4. Create the job folder `jobs/<company>-<role>/` with:
   - `job-post.md` — the job description (source URL in frontmatter).
   - `resume-custom.md` — the tailored resume.
   - `cover-letter.md` — the cover letter draft.
   - `notes.md` — which KB facts you used and what you omitted, and why.
5. Before writing, if the JD needs experience the KB does not clearly cover,
   ask the user concise clarifying questions.

Truthfulness rules apply: only reword/reframe real facts from the KB. Never
invent titles, dates, employers, skills, or metrics. If the JD demands
something the user hasn't done, omit or ask — never fabricate.

When done, tell the user which facts you used, what you cut, and confirm
everything is real. Offer to adjust emphasis based on the JD.