# How This Vault Works (Lawyer Persona)

This is your Brain — a persistent local memory system for AI-assisted legal research and document review.

## Core idea

You work with **matters** (the lawyer equivalent of "projects"). Each matter has:
- A **client** and a **type** (contract, litigation, advisory, drafting, regulatory)
- An **external folder** at `~/Legal/<slug>/documents/` for raw PDFs (default for doc-heavy matters; opt-out for note-only)
- A **Brain folder** at `_ActiveSessions/<slug>/` for status, sessions, summaries, and ingested document indexes
- A **memory pool** at `_Memory/<slug>/` for cross-session context

## Key directories

| Path | Purpose |
|------|---------|
| `_ActiveSessions/<slug>/` | Per-matter status (`_Status.md`) and recent session notes (`session.md`) |
| `_Memory/<slug>/` | Per-matter persistent facts (key clauses, parties, deadlines, decisions) |
| `_Profile/` | Your identity, practice area, working preferences |
| `_KnowledgeBase/` | Cross-matter reference notes (e.g., reusable clause language, jurisdiction quirks) |
| `_Log/` | Daily log of work across all matters |
| `_Workbench/` | Scratch space, quick notes |
| `_AgentTasks/<slug>/` | Plans and reports for larger pieces of work |
| `_matters.conf` | Matter registry — single source of truth for all matters |

## Daily workflow

1. Open Claude Code in the vault root (`cd ~/<vault-name>` then `claude`).
2. Tell Claude what matter you're working on. Brain loads the matter context (status, recent session, memory).
3. Use lawyer-specific skills:
   - `/create-matter` — start a new matter
   - `/ingest-document <path>` — parse a PDF, extract text with page markers
   - `/summarize-document` — summarize an ingested document with mandatory citations
4. End with `/save-session` to persist the conversation handoff for next time.

## Anti-hallucination policy

This vault enforces:
1. **Cite sources.** Any claim about a document must include document name + page/section. Any case-law claim must include citation.
2. **Flag out-of-corpus.** If the answer isn't in your ingested matter documents, output says so explicitly.
3. **No invented citations.** Skills forbid fabricating case names, page numbers, or section references.
4. **Loaded via CLAUDE.md.** This is a persona-level system rule, not per-skill.

## What this vault is NOT

- **Not for drafting client deliverables.** The AI helps you read, search, and understand — not produce client-facing output.
- **Not for client communication.** AI output stays in your private workflow.
- **Not a replacement for legal judgment.** It's an assistant for high-volume document work.

## Plan 1 limitations (current state)

- Only 3 lawyer skills shipped: `/create-matter`, `/ingest-document`, `/summarize-document`.
- `/search-matter` (search across ingested docs) ships in Plan 2.
- `/find-case-law` (CourtListener / Google Scholar search) ships in Plan 2.
- `/summarize-document --key-points` flag ships in Plan 2.
- DOCX support ships in Plan 2 (PDF-only for now).
- See `_AgentTasks/braintemplate/Plans/persona-branching-plan-mvp-2026-04-29.md` for scope.
