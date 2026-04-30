---
name: ingest-document
description: Parse a PDF document for a matter — extract text with page markers, store metadata, prepare for downstream summarization and search. Use when the user wants to "ingest", "load", "process" or "read in" a document.
allowed-tools: Read, Write, Edit, Bash
---

# /ingest-document

Parse a PDF and store its text + metadata in a matter's `documents/` directory inside Brain. Page markers are preserved so downstream summarization and search can cite specific pages.

## Plan 1 scope

- **Format support:** PDF only. DOCX deferred to Plan 2.
- **Size limit:** Designed for documents up to ~500 pages. Larger docs work but slow (Read tool is 20 pages per call).
- **Storage location:** `_ActiveSessions/<matter-slug>/documents/<doc-slug>/text.md` (page-marked text) and `metadata.yaml` (source path, size, date).
- **No search index built** — Plan 2 adds this.

## Inputs (ask user)

1. **Matter slug** — which matter does this document belong to? (Check `_matters.conf`; reject if not found.)
2. **Document path** — absolute path to the PDF. Validate file exists and ends in `.pdf`.
3. **Document slug** (optional) — defaults to filename without extension, lowercased and hyphenated.

## Steps

1. **Validate inputs.**
   - Matter exists in `_matters.conf`. If not, suggest `/create-matter` first.
   - PDF file exists at given path.
   - Document slug is unique within the matter (check `_ActiveSessions/<slug>/documents/`).

2. **Get page count.** Use `Read` tool on the PDF without `pages` parameter for ≤10 pages, or use a small test read first to determine count. If count is unknown, attempt reads in batches of 20 until reads start failing/empty.

   Alternative: shell out to a page count via `Bash`:
   ```bash
   # If pdfinfo is available (Poppler):
   pdfinfo "<path>" | grep "^Pages:" | awk '{print $2}'
   # If not, fall back to iterative Read until empty.
   ```

3. **Create directories.**
   ```bash
   mkdir -p "$BRAIN_ROOT/_ActiveSessions/<matter-slug>/documents/<doc-slug>"
   ```

4. **Read PDF in batches of 20 pages.** For a 100-page doc, that's 5 calls. Concatenate output with page markers:
   ```markdown
   <!-- page 1 -->
   [page 1 text]

   <!-- page 2 -->
   [page 2 text]

   ...
   ```

   Write the concatenated output to `_ActiveSessions/<matter-slug>/documents/<doc-slug>/text.md`.

5. **Write metadata.yaml** to the same directory:
   ```yaml
   doc_slug: <doc-slug>
   matter_slug: <matter-slug>
   source_path: <absolute path>
   filename: <basename>
   page_count: <N>
   ingested_at: <ISO 8601 UTC>
   format: pdf
   ```

6. **Update matter Status.** Append to `_ActiveSessions/<matter-slug>/_Status.md` under "Documents Ingested" section:
   ```markdown
   - <doc-slug> — <filename> (<N> pages, ingested <date>)
   ```

7. **Confirm to user.** Report: doc slug, page count, location of `text.md`. Note: "Run `/summarize-document <doc-slug>` next to generate a cited summary."

## Error handling

- PDF unreadable (corrupted, scan-only without OCR) → fail clearly: "Cannot extract text from this PDF. It may be a scan without OCR. Run OCR first (e.g., `ocrmypdf <path>`)."
- Read tool returns empty → assume end of pages, stop iterating.
- Write fails (permission, disk space) → fail loudly with full error.

## Anti-hallucination

- Page markers in `text.md` MUST match real PDF pages. Do not invent or skip page markers.
- If a page is unreadable, mark it `<!-- page N: UNREADABLE -->` rather than omitting it. Downstream skills know to flag this.
- Do NOT summarize or paraphrase during ingestion. Verbatim extraction only. Summarization is `/summarize-document`'s job.

## Example

User: "Ingest the master agreement at ~/Legal/acme-acquisition/documents/master-agreement.pdf for the acme-acquisition matter."
You: [validate matter exists, validate PDF exists, get page count = 412, create dirs, read PDF in 21 batches of 20 pages, concatenate with markers, write text.md and metadata.yaml, update status]
You: "Ingested `master-agreement` (412 pages) into matter `acme-acquisition`. Text at `_ActiveSessions/acme-acquisition/documents/master-agreement/text.md`. Run `/summarize-document master-agreement` for a cited summary."
