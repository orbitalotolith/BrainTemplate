---
name: summarize-document
description: Summarize an ingested document for a matter, with mandatory page citations for every claim. Use when user wants a "summary", "overview", or "key points" from an ingested document.
allowed-tools: Read, Write, Edit, Bash
---

# /summarize-document

Generate a structured summary of an ingested document. Every factual claim must cite the source document and page. Output is written to `_ActiveSessions/<matter-slug>/documents/<doc-slug>/summary.md`.

## Plan 1 scope

- Reads the page-marked `text.md` produced by `/ingest-document`.
- Produces a structured summary using the `_Templates/DocumentSummary.md` template.
- **Every section must cite specific pages.** No uncited claims.
- **Plan 2 will add `--key-points` flag** for structured extraction (parties, dates, etc.) using `_Templates/KeyPoints.md`.

## Inputs (ask user)

1. **Matter slug** (defaults to current active matter from session context).
2. **Document slug** — which ingested document to summarize.

## Steps

1. **Validate inputs.**
   - Matter exists in `_matters.conf`.
   - Document directory exists at `_ActiveSessions/<matter-slug>/documents/<doc-slug>/`.
   - `text.md` exists and is non-empty.

2. **Read text.md.** Use `Read` tool. For very large text files (thousands of pages of legal text), read in chunks if needed.

3. **Read template.** Read `_Templates/DocumentSummary.md` for the output structure.

4. **Generate summary.** Fill the template with content from `text.md`. CRITICAL RULES:
   - Every assertion must cite a page number from `text.md`'s `<!-- page N -->` markers.
   - If a claim spans multiple pages, cite all of them: `(p.42-44)` or `(p.42, p.51)`.
   - If `text.md` has `<!-- page N: UNREADABLE -->` markers, note any gaps explicitly: "Pages 47–48 were unreadable in source."
   - If a section of the template doesn't apply to this document, write `(not applicable)` rather than fabricating.
   - DO NOT include claims you cannot trace to a specific page.

5. **Write summary.md** to `_ActiveSessions/<matter-slug>/documents/<doc-slug>/summary.md`.

6. **Update matter Status.** Append to "Documents Summarized" section in `_ActiveSessions/<matter-slug>/_Status.md`:
   ```markdown
   - <doc-slug> — summary at `documents/<doc-slug>/summary.md` (<N> citations)
   ```

7. **Confirm to user.** Report: location of summary, citation count, any unreadable pages noted.

## Anti-hallucination enforcement (THIS SKILL'S CORE PURPOSE)

Before writing summary.md, verify:

1. Every paragraph contains at least one page citation in the format `(p.N)` or `(p.N, §X)` or `(p.N-M)`.
2. Every cited page number exists in `text.md` (grep for `<!-- page <N> -->`).
3. No invented section numbers (`§`) — only use section references that appear in `text.md`.
4. No claims beyond what's in `text.md`. If asked for context not in the document, respond: "Not in this document; recommend ingesting [other source] or running `/find-case-law`" (Plan 2).

If any of these checks fail, do NOT write the file. Surface the problem to the user.

## Example output (excerpt)

```markdown
# Document Summary: master-agreement.pdf

**Matter:** acme-acquisition
**Document:** master-agreement
**Pages:** 412
**Summarized:** 2026-04-29

## Parties (p.1)

- Acme Corp ("Buyer") — Delaware corporation, principal office Wilmington, DE (p.1)
- Beta Holdings LLC ("Seller") — California LLC, principal office San Francisco, CA (p.1)

## Term (p.3, §1.1)

Effective date: January 1, 2026. Closing: March 31, 2026 unless extended (p.3, §1.1).

## Indemnification cap (p.42, §8.2)

Capped at $5M for all claims excluding fraud (p.42, §8.2). Fraud claims uncapped (p.43).
```
