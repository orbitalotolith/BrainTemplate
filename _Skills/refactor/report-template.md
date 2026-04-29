# Refactor — Report Template

Report file location: `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/refactor-YYYY-MM-DD.md`

---

## Report Format

```markdown
# Refactoring Analysis — YYYY-MM-DD

## Summary
| Verdict      | Total | OPEN | APPLIED | SKIPPED |
|--------------|-------|------|---------|---------|
| RECOMMENDED  | 0     | 0    | 0       | 0       |
| CONSIDER     | 0     | 0    | 0       | 0       |
| NEUTRAL      | 0     | 0    | 0       | 0       |
| CAUTION      | 0     | 0    | 0       | 0       |
| REJECTED     | 0     | 0    | 0       | 0       |
| **Total**    | **0** | **0**| **0**   | **0**   |

## Decision Log

### Scope
- **Target:** [file/module/function path]
- **Additional scope:** [--scope arguments, if any]
- **Excluded:** [what was excluded and why]

### Security & Audit Context
- **Security audit report:** security-YYYY-MM-DD.md (N FIXED, M OPEN) [or "none found"]
- **Code audit report:** audit-YYYY-MM-DD.md (N FIXED, M OPEN) [or "none found"]
- **audit-context.json:** [summary of prior changes, or "no prior context"]
- **Architectural context:** [key decisions from _Status.md that shaped analysis]

## Security Posture

<Summary of security analysis from Section 2. Even if no security refactorings are needed, document what was checked and found sound.>

## Recommendations

<REF-001 through REF-NNN in severity order, each with Status field>

### REF-001 — Short title
- **Dimension:** [which analysis dimension]
- **Severity:** CRITICAL | HIGH | MEDIUM | LOW | COSMETIC
- **Effort:** SMALL | MEDIUM | LARGE
- **Confidence:** HIGH | MEDIUM | LOW
- **Status:** OPEN | APPLIED | SKIPPED
- **What:** [one sentence]
- **Why:** [concrete harm]
- **Pros:** [list]
- **Cons:** [list]
- **Security Impact:** POSITIVE | NEGATIVE | NEUTRAL — [one sentence]
- **Source:** [citation]
- **Ambiguity:** [if unclear, say so]
- **Verdict:** RECOMMENDED | CONSIDER | NEUTRAL | CAUTION | REJECTED — [justification]

## What Was NOT Recommended

<Refactoring ideas considered and rejected, with one-line reasons.>
```

---

## Finding ID Prefix

| Prefix | Meaning |
|--------|---------|
| `REF-` | Refactoring recommendation |

## Status Values

- `OPEN` — recommendation identified, not yet addressed
- `APPLIED` — recommendation implemented (code change made)
- `SKIPPED` — user chose to skip (via AskUserQuestion)
