# Contract — devlog-audit

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | Read-only. MUST NOT modify any files. |
| 2  | If zero findings, report clean and stop. MUST NOT manufacture findings. |
| 3  | Dynamic project discovery from `_projects.conf`. No hardcoded slugs. |
| 4  | MUST scan both vault-level DevLogs (`_DevLog/*.md`) and project-level DevLogs (`_DevLog/<slug>/`). Never only one level. |
