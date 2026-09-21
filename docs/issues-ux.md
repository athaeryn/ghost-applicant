# UX issues

All in the job-application web UI unless noted.

## 1. Colon-less tag input causes a 500

Typing `ruby` (no `taxonomy:` prefix) into the add-tag box on
`job_applications/show`: `Taggable#add_tags` gets `nil` back from
`find_or_create_tag` and calls `taggings.find_or_create_by!(tag: nil)`, which
raises `RecordInvalid` → error page. Validate the label format in
`add_tag` (and in `Taggable#add_tags` itself) and re-render with a message.

## 2. No feedback during generation

"Generate resume draft" / "Generate cover letter" / "Analyze" are plain
`button_to`s that hang for up to two minutes with no spinner or disabled
state. Quick fix: `data: { turbo_submits_with: "Generating…" }`. Real fix:
background jobs + Turbo Streams (see system-design doc).

## 3. Analyze results are opaque

The flash says "Analysis complete. 3 tags applied" but not *which* tags, and
there's no undo short of removing tags one by one. Show the applied tags in
the flash (or highlight newly added ones), and consider an "undo analysis"
that removes the just-added set.

Also: a silent JSON parse failure in the service currently looks identical to
"no tags matched" (see prompt-generation doc #5).

## 4. Draft navigation and comparison

- The Older/Newer links on `job_application_drafts/show` derive direction from
  `@drafts` order (`@drafts[index - 1]` labeled "← Older") — verify against
  the `chronological` scope; easy to get inverted.
- No diff view between two drafts. Comparing yesterday's draft against
  today's (after adding facts or changing guidance) is a core loop of this
  tool and currently requires eyeballing two tabs.

## 5. Dead/commented-out markup

`app/views/job_applications/index.html.erb:18-52` contains a large
commented-out table. It also has a latent bug: both the "resume" and "letter"
columns render `has_favorited_resume_draft`. Finish it or delete it.

## 6. Favorite star is display-only on the list

On `job_applications/show`, the ★ next to each draft reflects favorited state
but isn't clickable; toggling requires opening the draft. Make it a button.

## 7. No PDF/print path

The end product is a resume to submit somewhere. A print stylesheet on the
draft page (`@media print`: hide chrome, tighten `.prose`) gives a usable
PDF via the browser print dialog nearly for free.

## 8. Cosmetics

- `border border-2` appears throughout — `border` is redundant next to
  `border-2`.
- Status on `show` is plain uppercase text; the index colors `archived`
  differently but other statuses (offer/rejected/interviewing) could use
  distinct treatment too.
