# Contract — pull-projectshared

Behavioral invariants for this skill. Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| BHV-001 | MUST check for unpushed local brain changes before pulling. If found, warn and default to abort. User must explicitly confirm to proceed. Skip check if no LAST_PUSH_COMMIT exists (first pull) or LAST_PUSH_COMMIT is stale. |
| BHV-002 | MUST show verification display (per-file diffs between Brain canonical and pulled content) BEFORE writing to Brain. User must confirm after reviewing. Allow Q&A. |
| BHV-003 | MUST write pulled content to Brain canonical locations before restoring symlinks. |
| BHV-004 | Memory, DevLog, and Workbench sync MUST be additive — never delete local files during pull. |
| BHV-005 | MEMORY.md MUST be auto-merged on pull (combine lines, deduplicate, sort). |
| BHV-006 | MUST restore symlinks and set assume-unchanged flags after pull — even if interrupted or user aborts after verification. |
| BHV-007 | MUST update `_sync.conf` SHARED_PROJECTS entry after every successful pull. |
| BHV-008 | If pull fails (not fast-forward, network), exit cleanly. Never partially apply changes. Keep assume-unchanged flags in their current state. |
| BHV-009 | MUST show partner status from session.md after pull. |
| BHV-010 | CLAUDE.md, session.md, _Status.md are authoritative override (pulled version wins). Memory, DevLog, Workbench are additive only. |
| BHV-011 | assume-unchanged flags MUST remain set during `git pull`. Clear only after pull completes. |
