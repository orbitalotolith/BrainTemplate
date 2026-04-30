# Contract — security-audit

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | Without `--dry-run` explicitly omitted, the skill defaults to reporting only. It must not apply fixes unless the user has confirmed via AskUserQuestion after seeing the full findings list. |
| 2  | `audit-context.json` must be written to `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/` (not to the source repo). The skill must never write audit artifacts into the project's source tree. |
| 3  | Secrets detection (section 1) must complete before any other audit category. If a committed secret is found, the skill must surface it as CRITICAL and require acknowledgment before continuing. |
| 4  | Dependency health checks must use the project's actual package manager (npm, cargo, pip, etc.) — not inferred from file extension or directory name alone. |
| 5  | The skill is foundational: `code-audit` and `refactor` may read `audit-context.json` it produces. Any change to the format of `audit-context.json` is a breaking change and must be flagged explicitly in the output. |
| 6  | When `--resume` is used, the skill must re-read the most recent report from `_AgentTasks/<slug>/Reports/` and continue from the first unresolved finding. It must not re-scan the entire codebase or re-apply already-fixed findings. |
| 7  | The skill must never auto-commit or auto-push changes. All file modifications are staged for user review. |
