# Code Audit — Report Template

Report file location: `$BRAIN_ROOT/_Docs/<slug>/Reports/audit-YYYY-MM-DD.md`

---

## Report Format

```markdown
# Code Audit Report — YYYY-MM-DD

## Summary
| Category              | Total | OPEN | FIXED | SKIPPED |
|-----------------------|-------|------|-------|---------|
| Shared Types          | 0     | 0    | 0     | 0       |
| Duplicates            | 0     | 0    | 0     | 0       |
| Imports               | 0     | 0    | 0     | 0       |
| Naming                | 0     | 0    | 0     | 0       |
| Lint                  | 0     | 0    | 0     | 0       |
| Quality               | 0     | 0    | 0     | 0       |
| Dead Code             | 0     | 0    | 0     | 0       |
| Root Hygiene          | 0     | 0    | 0     | 0       |
| **Total**             | **0** | **0**| **0** | **0**   |

## Decision Log

### Scope
- **Source paths:** [detected paths and how they were detected]
- **Files scanned:** [count] files across [count] directories
- **Excluded:** [what was excluded and why]

### Category Applicability
| Category | Applied? | Reasoning |
|----------|----------|-----------|
| Shared Types | Yes/No | [why] |
| Duplicates | Yes | Always applies |
| Imports | Yes | Always applies |
| Naming | Yes | Always applies |
| Lint | Yes | Always applies |
| Quality | Yes | Always applies |
| Dead Code | Yes/No | [whether --dead-code was passed or full audit] |
| Root Hygiene | Yes | Always applies |

### Security & Architecture Context
- **Security audit report:** security-YYYY-MM-DD.md (N FIXED, M OPEN) [or "none found"]
- **Security-modified files:** [list from audit-context.json, or "none"]
- **Architectural context:** [key decisions from _Status.md that shaped refactoring choices]
- **Constraint applied:** Code quality fixes in security-modified files preserve security remediations

### Reasoning Notes
- **[FLAGGED] QUA-003** eval() in src/utils/transform.ts:42 — processes user input at runtime
- **[NOT FLAGGED]** eval() in test/helpers/mock.ts:15 — test-only, no production path
- **[SEVERITY]** QUA-005 rated HIGH — race condition in concurrent request handler

## Root Causes
| ID    | Class of Problem           | Systemic Gap                        | Findings            |
|-------|----------------------------|-------------------------------------|---------------------|
| RC-01 | [class name]               | [what convention/tooling is missing] | NAM-001, NAM-002    |

### RC-01 — [Class name]
- **Systemic gap:** What convention, tooling, or pattern is missing
- **Principle fix:** What to add to prevent this class of problem (e.g., linter rule, shared module, CI check, documented convention)
- **Instance cleanup:** What existing occurrences need fixing after the systemic fix is in place
- **Affected findings:** [list of finding IDs]

## Findings
| ID      | Severity | Category | Status  | File:Line         | Description                  |
|---------|----------|----------|---------|-------------------|------------------------------|

## Details
(One subsection per finding)

### XXX-001 — Short title
- **Severity:** HIGH | MEDIUM | LOW
- **Status:** OPEN | FIXED | SKIPPED
- **Root Cause:** RC-XX — [class name] (omit if this is a one-off with no systemic gap)
- **Location:** file/path.ts:42
- **Description:** What the issue is
- **Remediation:** How to fix it (instance-level fix; systemic fix is in the RC entry)
```

---

## Finding ID Prefixes

| Prefix | Category |
|--------|----------|
| `TYP-` | Shared types consistency |
| `DUP-` | Duplicate code |
| `IMP-` | Import/module consistency |
| `NAM-` | Naming conventions |
| `LNT-` | Language-specific lint |
| `QUA-` | Quality |
| `DEA-` | Dead code |
| `ROO-` | Root hygiene |

## Status Values

- `OPEN` — finding identified, not yet addressed
- `FIXED` — Claude fixed the issue (code change made)
- `SKIPPED` — user chose to skip (via AskUserQuestion)
