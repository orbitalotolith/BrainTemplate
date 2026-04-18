# Contract — vault-consistency-audit

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | Read-only. MUST NOT modify any files. |
| 2  | If zero findings, report clean and stop. MUST NOT manufacture findings. |
| 3  | Dynamic project discovery from `_projects.conf`. No hardcoded slugs. |
| 4  | XPC-DOCRIFT checks MUST compare _HowThisWorks.md against actual filesystem state. Never accept documentation at face value. |
| 5  | Symlink checks MUST only run for projects whose code repo directory exists on disk. Skip gracefully for uncloned repos. |
