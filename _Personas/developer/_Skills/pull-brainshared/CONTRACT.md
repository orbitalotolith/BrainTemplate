# Contract — pull-brain

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | pull-brain MUST only pull from the BrainShared repo configured in _sync.conf (SHARED_BRAIN_REMOTE). Never pull from any other remote. |
| 2  | MUST check for unpushed local changes to shared content before overwriting. If found, warn and default to abort (user must explicitly confirm to proceed). |
| 3  | _Memory/brain/ sync MUST be additive only (no --delete). Never remove personal global memories. |
| 4  | MUST NOT sync _Profile/, _projects.conf, or _DevLog/ — these are always private, never pulled from shared. |
| 5  | MUST invoke /brain-check after sync to propagate changes to ~/.claude/ and validate vault integrity. |
| 6  | MUST update _sync.conf with new LAST_PULL_COMMIT and LAST_PULL_DATE after every successful pull. |
| 7  | If clone fails (offline, auth error), exit cleanly. Never partially apply changes from a failed clone. |
| 8  | MUST NOT `rsync --delete` mixed directories (`_ClaudeSettings/`, `_Memory/`) at the parent level. Sync only the subdirectories that exist in BrainShared. Local-only subdirectories must be untouched. |
| 9  | MUST show verification display (per-file diffs between Brain canonical and pulled content) BEFORE writing to Brain. User must confirm after reviewing. Allow Q&A. If user aborts, exit cleanly — never partially apply changes. |
