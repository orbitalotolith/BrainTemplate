# Contract — push-projectshared

Behavioral invariants for this skill. Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| BHV-001 | MUST only stage and commit files under `project_files/brain/` (excluding `_AgentTasks`). Never stage code changes through this skill. |
| BHV-002 | MUST dereference symlinks before commit and restore them after — even if push fails or is cancelled. |
| BHV-003 | Every changed brain file from partner MUST be presented for review. Never silently overwrite partner changes. |
| BHV-004 | MUST fetch remote and check for partner changes before pushing. If partner changed brain files, interactive merge is required. |
| BHV-005 | MUST NOT push without explicit user confirmation after showing the diff summary. |
| BHV-006 | MUST update `_sync.conf` SHARED_PROJECTS entry after every successful push. |
| BHV-007 | MUST restore symlinks and set assume-unchanged flags even if push fails or is cancelled. |
| BHV-008 | Pre-commit checks (git identity, no secrets, no attribution lines) MUST run before committing. Follows `/commit` hygiene rules without invoking `/commit`. |
| BHV-009 | Maximum 2 push retry attempts on race condition (non-fast-forward). After second failure, restore symlinks and stop. |
| BHV-010 | session.md sections merge by identity (different `## identity` sections combine; same section = prefer local). MEMORY.md auto-merges (deduplicate, sort). |
| BHV-011 | assume-unchanged flags MUST remain set during `git pull`. Clear only after pull completes. |
| BHV-012 | If LAST_PUSH_COMMIT is missing or not in history, treat as first push — full interactive review of all remote brain file diffs. Log warning if stale. |
