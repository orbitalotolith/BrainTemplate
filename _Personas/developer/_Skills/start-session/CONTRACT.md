# Contract — start-session

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | MUST resolve project identity from `_projects.conf` (longest CODE_PATH prefix match). Never assume project from directory name alone. |
| 2  | MUST present the last session handoff (what was being worked on, where it left off, next steps) before asking the user how to proceed. Never prompt without context. |
| 3  | Read-only — MUST NOT modify any files. |
| 4  | MUST NOT load DevLog archives, Claude memory files, KnowledgeBase, or project CLAUDE.md. Only session.md and _Status.md. |
