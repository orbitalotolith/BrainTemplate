# Skill Audit — Report Template

Templates for terminal output and report file. Read by `SKILL.md` during report phase.

---

## Terminal Summary (Full/Lint)

```
## Skill Audit — YYYY-MM-DD (<mode>)

Self-audit: <N> findings (<clean|N errors, N warnings>)

| Skill | FMT | SEC | NAM | GOT | FIT | INV | SCP | CMP | BHV | Status |
|-------|-----|-----|-----|-----|-----|-----|-----|-----|-----|--------|
| <name> | N | N | N | N | N | N | N | N | N/— | <summary> |

Totals: <N> skills scanned
  Errors: <N> (auto-fixable)
  Warnings: <N> (auto-fixable)
  Recommendations: <N> (require review)
  Contract violations: <N> (require review)
  Suppressed: <N>
  Clean: <N> skills
```

## Terminal Summary (Lint-Only, Compact)

```
Skill lint: <N> skills, <N> errors, <N> warnings
  <skill>: <finding-id> (<description>), <finding-id> (<description>)
  ...
Fix? (all / errors only / report only)
```

## Terminal Summary (Analyze-Only)

Use the full summary table but only show FIT/INV/SCP/CMP/BHV/GOT columns.

## Report File (`$BRAIN_ROOT/_AgentTasks/<slug>/Reports/skill-audit-YYYY-MM-DD.md`)

```markdown
# Skill Audit Report — YYYY-MM-DD

## Summary
| Category | Errors | Warnings | Info | Recommendations |
|----------|--------|----------|------|-----------------|
| FMT      | N      | N        | N    | —               |
| SEC      | N      | N        | N    | —               |
| NAM      | N      | N        | N    | —               |
| GOT      | N      | N        | N    | N               |
| BHV      | N      | —        | —    | —               |
| FIT      | —      | —        | —    | N               |
| INV      | —      | —        | —    | N               |
| SCP      | —      | —        | —    | N               |
| CMP      | —      | —        | —    | N               |

## Findings
| ID | Severity | Skill | Description | Status |
|----|----------|-------|-------------|--------|
| <id> | <severity> | <skill> | <description> | OPEN |

## Recommendations
| ID | Skill | Category | Recommendation | Status |
|----|-------|----------|----------------|--------|
| <id> | <skill> | <category> | <recommendation> | OPEN |

## Details
(One subsection per finding/recommendation with full reasoning)

## Suppressions
(Carried forward from suppressions.md)
```

**Status values:** `OPEN`, `FIXED`, `SKIPPED`, `SUPPRESSED`

---

## Interactive Repair Menu

```
Skill audit complete: <N> errors, <N> warnings, <N> recommendations, <N> contract violations

How to proceed?
- Fix all mechanical — auto-fix all FMT/SEC/NAM/GOT findings
- Fix errors only — auto-fix mechanical errors, skip warnings
- Review violations + recommendations — walk BHV violations first, then judgment findings
- Fix all + review — auto-fix mechanical, then walk violations and recommendations
- Report only — stop here
```

## Contract Violation Walk Format (BHV)

```
[<ID>] <skill> — contract violation
  Contract invariant <N>: "<invariant text>"
  SKILL.md <step reference>: "<process step text>"
  Gap: <specific gap description>

  → Fix SKILL.md to satisfy the invariant
  → Update CONTRACT.md (invariant is too strict)
  → Defer (revisit later)
```

## Judgment Recommendation Walk Format

```
[<ID>] <skill> (<category>)
  <explanation with evidence>

  → <action option 1>
  → <action option 2>
  → Keep as-is (document reasoning)
  → Defer (revisit later)
```
