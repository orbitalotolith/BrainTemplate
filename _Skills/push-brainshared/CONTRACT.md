# Contract — push-brain

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | push-brain MUST only push to the BrainShared repo configured in _sync.conf (SHARED_BRAIN_REMOTE). Never push to any other remote. |
| 2  | Safety check MUST run before pushing. If any private path (_Profile/, _projects.conf, _DevLog/, _sync.conf) is detected in the push directory, abort immediately. No exceptions. |
| 3  | Every non-identical file MUST be presented to the user for per-file decision. Never silently resolve differences — the user decides for every file (use mine, use theirs, merge). |
| 4  | MEMORY.md index files are the only exception to invariant 3 — always auto-merged (combine lines, deduplicate, sort). |
| 5  | MUST NOT push without user confirmation. Show summary and ask before `git push`. |
| 6  | MUST update _sync.conf with new LAST_PUSH_COMMIT and LAST_PUSH_DATE after every successful push. |
| 7  | Maximum 2 push retry attempts on race condition (non-fast-forward). After second failure, stop and tell the user. |
