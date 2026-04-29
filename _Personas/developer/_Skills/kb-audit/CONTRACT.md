# Contract — kb-audit

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | Read-only. MUST NOT modify any files. |
| 2  | If zero findings, report clean and stop. MUST NOT manufacture findings. |
| 3  | Every KB entry MUST be evaluated for version context. Entries without "as of X" or version tags are flagged (KBF-VERSION). |
