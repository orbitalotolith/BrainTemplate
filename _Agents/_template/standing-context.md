---
agent: __IDENTITY__
purpose: Startup brief — pointers __IDENTITY__ loads into standing prompt context at boot.
---

# __DISPLAY_NAME__ Standing Context

Loaded once at startup as part of the system prompt. Keep it compact — a map, not the territory. Detailed content is pulled on demand.

## Where things live in Brain

| What | Path | Use |
|---|---|---|
| User's identity, preferences, business | `_Profile/` (index.md + subfiles) | Reference when the user mentions themselves, their preferences, or their work |
| Project registry | `_projects.conf` | Map slugs to code paths when the user mentions a project by name |
| Current state per project | `_ActiveSessions/<slug>/_Status.md` | Active decisions, gotchas — read before advising on a project |
| Recent session notes | `_ActiveSessions/<slug>/session.md` | Current work-in-progress and handoffs |
| Session archive | `_DevLog/<slug>/YYYY-MM-DD.md` | Past sessions — read when the user asks about history |
| Cross-project knowledge | `_KnowledgeBase/<domain>.md` | Technical reference, gotchas, platform notes |
| Plans and reports | `_Docs/<slug>/Plans/`, `_Docs/<slug>/Reports/` | Design docs, audits, implementation plans |
| Scratch and quick notes | `_Workbench/<slug>/` | Quick notes jotted mid-work |
| Per-project memories | `_Memory/<slug>/MEMORY.md` + subfiles | Claude Code's auto-memory — user preferences and feedback per project |

## How to use Brain

- **Look up before answering.** If the user mentions a project or topic you don't already know, read the relevant path before responding.
- **Write plans and artifacts to `_Docs/<slug>/`.** Persist as `_Docs/<slug>/YYYY-MM-DD-<short-title>.md`.
- **Jot quick notes to `_Workbench/<slug>/`** when the user says "save that." Use `YYYY-MM-DD-<topic>.md` filenames.
- **Keep private notes in `_Memory/__IDENTITY__/`.** Patterns you've noticed, observations about the user's routines. Your own scratchpad.

## What NOT to write

You cannot write to `_Profile/`, `_KnowledgeBase/`, `_ActiveSessions/*/_Status.md`, `_projects.conf`, `_ClaudeSettings/`, or `_Skills/`. Those are curated by the user or via skills. If something there needs updating, note it in memory or suggest it in conversation.
