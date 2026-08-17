# Case studies

Real, detailed pieces of work the user completed — deep material for both the
knowledge base and for matching voice/tone on narrative-heavy writing.

Add one file per study: `knowledge/case-studies/<slug>.md`

Convert PDFs/text originals to markdown so the model can read them.

Frontmatter template:

```markdown
---
type: case-study
title: <short title>
date: YYYY-MM
format-of-original: <pdf/docx/...>
related-role: <optional link to a role file, if any>
---

# The study

(Preserve the case study's own wording — its rhythm and voice matter for
tone-matching.)

## Facts worth remembering

Call out the specifics the model may reuse: context, actions, outcomes,
numbers — only what is true and present in the source.
```

## How the model uses these

- As a knowledge source: cite real facts from them where relevant.
- As a voice reference: the study's phrasing and structure inform the
  author's narrative style.