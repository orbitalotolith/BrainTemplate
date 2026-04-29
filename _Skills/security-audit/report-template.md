# Security Audit — Report Template

Report file location: `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/security-YYYY-MM-DD.md`

---

## Report Format

```markdown
# Security Audit Report — YYYY-MM-DD

## Summary
| Category              | Total | OPEN | FIXED | SKIPPED |
|-----------------------|-------|------|-------|---------|
| Secrets               | 0     | 0    | 0     | 0       |
| Code Vulnerabilities  | 0     | 0    | 0     | 0       |
| Configuration         | 0     | 0    | 0     | 0       |
| Dependencies          | 0     | 0    | 0     | 0       |
| Deployment            | 0     | 0    | 0     | 0       |
| **Total**             | **0** | **0**| **0** | **0**   |

## Decision Log

### Scope
- **Source paths:** [detected paths and how they were detected]
- **Files scanned:** [count] files across [count] directories
- **Excluded:** [what was excluded and why]

### Category Applicability
| Category | Applied? | Reasoning |
|----------|----------|-----------|
| Secrets | Yes | Always applies |
| Code Vulnerabilities | Yes | Always applies |
| Configuration | Yes/No | [why] |
| Dependencies | Yes/No | [why] |
| Deployment | Yes/No | [why — include detected project type] |

### Reasoning Notes
- **[FLAGGED] VUL-001** eval() in src/utils/transform.ts:42 — processes user input at runtime
- **[NOT FLAGGED]** eval() in test/helpers/mock.ts:15 — test-only, no production path
- **[NOT FLAGGED]** innerHTML in RichText.tsx:28 — sanitized via DOMPurify on line 22
- **[SEVERITY]** SEC-001 rated CRITICAL — API key in public repo with write access

## Root Causes
| ID    | Class of Problem           | Systemic Gap                        | Findings            |
|-------|----------------------------|-------------------------------------|---------------------|
| RC-01 | [class name]               | [what convention/tooling is missing] | SEC-001, SEC-002    |

### RC-01 — [Class name]
- **Systemic gap:** What convention, tooling, or pattern is missing
- **Principle fix:** What to add to prevent this class of problem (e.g., pre-commit hook, middleware pattern, `.env` convention)
- **Instance cleanup:** What existing occurrences need fixing after the systemic fix is in place
- **Affected findings:** [list of finding IDs]

## Findings
| ID      | Severity | Category | Status  | File:Line         | Description                  |
|---------|----------|----------|---------|-------------------|------------------------------|

## Details
(One subsection per finding)

### XXX-001 — Short title
- **Severity:** CRITICAL | HIGH | MEDIUM | LOW
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
| `SEC-` | Secrets detection |
| `VUL-` | Code vulnerabilities |
| `CFG-` | Configuration issues |
| `DEP-` | Dependency health |
| `DPL-` | Deployment readiness |

## Status Values

- `OPEN` — finding identified, not yet addressed
- `FIXED` — Claude fixed the issue (code change made)
- `SKIPPED` — user chose to skip (via AskUserQuestion)
