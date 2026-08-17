---
description: Add past cover letters, PDF case studies, or writing samples to the knowledge base and learn your voice from them.
---

Ingest the document(s) the user is providing into the knowledge base and derive
their writing voice. Follow the ingest skill.

$ARGUMENTS

Steps:
1. Obtain the content from the user — pasted text or a file path (docx, PDF,
   md). If a path, read and convert it (PDFs → markdown). Convert PDFs via the
   `markitdown` MCP tool if loaded; otherwise drop the file into `ingest/` and
   run `node scripts/convert-ingest.mjs`, then read the `.md` from
   `ingest/converted/`.
2. Store it faithfully in `knowledge/samples/cover-letters/` (past letters) or
   `knowledge/case-studies/` (case studies / deep writing), preserving wording.
3. Derive the user's voice into `knowledge/_profile.md` ("Voice / letter style")
   and `knowledge/letters.md` (patterns that worked, what to avoid).
4. Show the user the concrete style traits you found and confirm before they
   rely on it.

Record only what is actually in the user's own material — never add facts.