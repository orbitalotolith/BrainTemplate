# Contract — brain-check

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | MUST run `_setup.sh` before `_health-check.sh`. Setup fixes issues that health check would otherwise report. |
| 2  | If `_setup.sh` fails with a non-zero exit, MUST stop and show the error. Do not run `_health-check.sh` on broken state. |
| 3  | Works from any directory. Brain root is detected via `$BRAIN_ROOT` or filesystem scan — no CWD dependency. |
| 4  | Read-only validation — does not modify files beyond what `_setup.sh` does (which is idempotent). |
