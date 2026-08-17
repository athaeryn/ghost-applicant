---
name: ingest
description: Ingest a source document (past cover letter, PDF case study, writing sample) into the resume knowledge base and derive the user's voice. Use when the user wants to add/upload/import a document to the KB to learn their writing tone, or says "ingest", "learn my voice", "here's a letter", "here's a case study", "process this PDF". Do NOT use for tailoring resumes or writing new letters (that is the resume skill).
---

# Ingesting documents into the knowledge base

Eat a real source document the user provides, store it as markdown in the
knowledge base, and learn the author's voice from it. Truthfulness applies:
only record what is actually in the user's own material — never add fabricated
facts or embellish.

## Which kind of document?

| Type                    | Store to                                         |
| ----------------------- | ------------------------------------------------ |
| Past cover letter       | `knowledge/samples/cover-letters/<slug>.md`      |
| Case study / deep write-up | `knowledge/case-studies/<slug>.md`             |
| Other writing samples   | `knowledge/samples/` (subfolder if needed)       |

A note one-line at the top of the stored file if there are multiple obvious
groups (e.g. `cover-letters/kind-of-role/`).

## Steps

1. **Obtain the content.** The user may paste text or give a file path (docx,
   PDF, md, etc.). If it's a path, read/convert it.
   - If the `markitdown` MCP tool is available, call its `convert_to_markdown`
     tool (passed a file:// URI or absolute path) to extract text as markdown.
   - If the MCP tool is NOT loaded in this session, do NOT try to read the PDF
     directly — the model cannot view PDF attachments. Instead:
       1. Have the user (or yourself) drop the raw file into `ingest/`.
       2. Run `node scripts/convert-ingest.mjs` (or the user runs it
          themselves) to convert every file there.
       3. Read the resulting `<name>.md` from `ingest/converted/`.
2. **Store it faithfully.** Copy the document into the right file per the table
   above, preserving wording and rhythm. Keep frontmatter consistent with the
   folder's README (type, date, target company/role, original format).
3. **Derive the user's voice — not just the text.** Read every sample and
   extract concrete, non-generic traits:
   - How letters open (direct first line vs. formal salutation).
   - Sentence/paragraph length tendencies; formal vs. conversational.
   - Signature phrases, transitions, and how each closes.
   - Recurring claims/angles and the structure.
   - Formatting quirks (headers, sign-off, bullets vs. paragraphs).
4. **Update the derived-voice files:**
   - `knowledge/_profile.md` → "Voice / letter style" section.
   - `knowledge/letters.md` → "patterns that worked" and "what to avoid."
5. **Report what you found.** Show the user the specific style traits you
   extracted so they can sanity-check before relying on it.

## Rules

- Only record facts that are actually in the source document.
- Keep the source document in verbatim, and put interpretation (voice) in
  `_profile.md` / `letters.md`, not in the sample file.
- Do not auto-inventory or rewrite the resume from here; that's the resume
  skill's job. Just ingest and derive voice unless asked to do more.