# Past cover letters (with their job context)

These are real letters the user has written/sent. They are the primary source
for matching the user's own voice and letter structure. Each file records the
letter plus the context it was written for.

Add one file per letter: `knowledge/samples/cover-letters/<target]-<dateor-slug>.md`

Frontmatter template:

```markdown
---
type: cover-letter
delivered: true
target-role: <role applied to>
target-company: <company, or other>
date: YYYY-MM
source-format: <original file format, e.g. .docx/.md>
---

# Reproduced letter

(verbatim as close as possible)

# Context notes

Which job/ad, what angle the letter took, what you emphasized.
```

## How the model uses these

When drafting a new cover letter, use the recurring structure and voice traits
here (formal? conversational? opener style? how each letter opens and closes)
rather than defaulting to a generic professional voice.