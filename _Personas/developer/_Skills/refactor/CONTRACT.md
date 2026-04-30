# Contract — refactor

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | Without `--apply` or `--apply-all`, the skill is read-only. It must not modify any source file during analysis mode. If the skill accidentally stages or modifies a file during analysis, that is a violation. |
| 2  | Every recommendation must include a sourced rationale (citation, principle, or named pattern). Recommendations without sources must not appear in the output. |
| 3  | Security findings are always reported separately and first, before other recommendations. A refactor that improves code quality but introduces a security regression must not be marked RECOMMENDED. |
| 4  | When `--apply <ID>` is used, the skill must apply only that specific recommendation. It must not apply adjacent or "obviously related" changes that were not part of the recommendation. |
| 5  | The skill must not apply any recommendation that would change the public API surface (exported functions, method signatures, types) without explicit user confirmation via AskUserQuestion. |
| 6  | If `security-audit` has produced an `audit-context.json` for this project, the skill must read it before forming security recommendations — to avoid re-reporting already-known issues. |
| 7  | Code that contains a recent security fix (as determined by git blame within the last 90 days) must not be flagged as a refactoring target without first checking whether the complexity is load-bearing. |
