# Contract — save-lightweight

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | Must read existing session file before modifying it |
| 2  | Must never overwrite existing handoff content — append or update in place only |
| 3  | Must never modify another identity's section in universal format files |
| 4  | Must derive code state from git commands only, never from conversation context or session memory |
| 5  | Must not perform knowledge capture (no KB, memory, profile, CLAUDE.md, _Status.md writes) |
| 6  | Must write timestamp only after session file is successfully updated |
| 7  | Must only write to session and status files matching the resolved slug — never to files for a different project |
