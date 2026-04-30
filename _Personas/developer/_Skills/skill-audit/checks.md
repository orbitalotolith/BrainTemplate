# Skill Audit — Check Catalog

Reference tables for all checks. Read by `SKILL.md` during lint and analyze phases.

---

## Lint Checks (Mechanical)

Deterministic, auto-fixable. Each finding gets an ID.

### FMT — Frontmatter

| ID | Severity | Check |
|----|----------|-------|
| FMT-001 | error | Missing required field (`name`, `description`, `user-invocable`, `disable-model-invocation`, `allowed-tools`) |
| FMT-002 | error | `name` doesn't match directory name |
| FMT-003 | warn | `description` is quoted (should be unquoted) |
| FMT-004 | warn | `description` doesn't start with verb or "Use when" |
| FMT-005 | error | Fields out of canonical order |
| FMT-006 | warn | `allowed-tools` includes tools not referenced anywhere in body |
| FMT-007 | warn | Body references a tool not in `allowed-tools` |

### SEC — Section Structure

| ID | Severity | Check |
|----|----------|-------|
| SEC-001 | error | Missing required section (`# Title`, `## Overview`, `## Process`, `## Output`, `## Rules`) |
| SEC-002 | error | Required sections out of canonical order |
| SEC-003 | warn | `## Arguments` section missing but body references flags/args |
| SEC-004 | warn | Section exists that doesn't match any canonical or optional section name |
| SEC-005 | info | Skill exceeds 200 lines — candidate for companion file extraction |

### NAM — Naming

| ID | Severity | Check |
|----|----------|-------|
| NAM-001 | error | Directory name doesn't match `name` frontmatter field |
| NAM-002 | warn | Directory name uses underscores instead of hyphens |
| NAM-003 | warn | Companion `.md` files don't follow `lowercase-hyphenated.md` convention |

### GOT — Gotchas (Lint)

| ID | Severity | Check |
|----|----------|-------|
| GOT-001 | info | `gotchas.md` doesn't exist — skill has never logged a gotcha |
| GOT-002 | warn | `gotchas.md` exists but isn't referenced from `SKILL.md` |
| GOT-003 | warn | `gotchas.md` has entries older than 90 days — recommend review |
| GOT-004 | error | `SKILL.md` doesn't include `### 0. Read Gotchas` as first process step |

---

## Analyze Checks (Judgment)

Requires reading full skill content and reasoning. Not auto-fixable — reported as recommendations requiring user decision.

### FIT — Fitness & Necessity

| ID | Category | What it evaluates |
|----|----------|-------------------|
| FIT-001 | Redundancy | Skill overlaps with another local skill or superpowers plugin skill. Evaluate using three questions: (1) same trigger — would the same user prompt reasonably invoke both? (2) stolen steps — does this skill re-implement a phase that another skill already owns as its core purpose? (3) user confusion — would a user be unsure which to run? Flag if 2+ questions are yes. |
| FIT-002 | Decomposition | Skill handles multiple distinct responsibilities. Recommend splitting if responsibilities could operate independently. |
| FIT-003 | Skill vs Agent | Skill is mostly "run these commands and return output" with no process discipline or decision logic. Would work better as an agent task. |
| FIT-004 | Necessity | Skill wraps trivial behavior that Claude would do correctly without a skill. Recommend retiring. |
| FIT-005 | Retirement | Skill is stale — references files/tools/patterns that no longer exist. |

### INV — Invocability

| ID | Category | What it evaluates |
|----|----------|-------------------|
| INV-001 | Should be agent-invocable | `disable-model-invocation: true` but description uses trigger language suggesting agents should detect and invoke it. |
| INV-002 | Should NOT be agent-invocable | `disable-model-invocation: false` but skill is destructive, slow, or requires user intent. |
| INV-003 | Should be user-invocable | `user-invocable: false` but skill has a clear `/command` use case. |
| INV-004 | Should NOT be user-invocable | `user-invocable: true` but skill is an internal helper only called by other skills. |

### SCP — Scope & Generalization

| ID | Category | What it evaluates |
|----|----------|-------------------|
| SCP-001 | Over-generalized | Skill handles every project type but actual use is narrow. Recommend scoping down. |
| SCP-002 | Under-generalized | Skill hardcodes project-specific paths/names when logic is universal. Recommend abstracting. |
| SCP-003 | Hardcoded living data | Skill duplicates rules from `_HowThisWorks.md`, `key-to-dev.md`, or `_projects.conf` instead of reading at runtime. |

### CMP — Companion File Opportunities

| ID | Category | What it evaluates |
|----|----------|-------------------|
| CMP-001 | Output template extraction | Body contains large formatted output blocks (>20 lines). Recommend extracting to companion. |
| CMP-002 | Reference table extraction | Skill contains lookup tables or check catalogs maintainable separately. |
| CMP-003 | Existing companions unlinked | `.md` files exist in skill directory but aren't referenced from `SKILL.md`. |

### BHV — Behavioral Contract

Only runs for skills with a `CONTRACT.md` companion file. Presence of `CONTRACT.md` = critical skill.

| ID | Category | What it evaluates |
|----|----------|-------------------|
| BHV-001 | Missing invariant | `CONTRACT.md` lists an invariant but no corresponding step exists in `SKILL.md` |
| BHV-002 | Weakened invariant | Invariant behavior exists but has been weakened (e.g., "ask on every discrepancy" but process allows batch confirm) |
| BHV-003 | Hardcoded override | Contract says "read X at runtime" but skill hardcodes the content X would provide |
| BHV-004 | Silent action | Contract says "must ask/confirm before X" but a process path performs X without user interaction |
| BHV-005 | Missing contract | Skill meets contract criteria but has no `CONTRACT.md`. Recommendation — walk user through creating one. |

BHV-001 through BHV-004 are always errors, never warnings. Never auto-fixed.
BHV-005 is a recommendation (not an error) — it suggests a contract should exist, not that one is violated.

### GOT — Gotchas (Analyze)

| ID | Category | What it evaluates |
|----|----------|-------------------|
| GOT-005 | Recurring gotcha | Same root cause appears 2+ times. Skill process has a structural gap — recommend updating `SKILL.md`. |
| GOT-006 | Mitigation not absorbed | Gotcha describes a fix but `SKILL.md` was never updated to include it. After absorption is applied and verified, mark the gotcha entry `[absorbed]`. |
| GOT-007 | Gotcha contradicts skill | Gotcha reveals a step produces wrong results under certain conditions, but step hasn't been updated. |
| GOT-008 | Gotcha suggests decomposition | Multiple gotchas cluster around one section. Feeds into FIT-002. |

---

## Mechanical Auto-Fixes

| Finding | Fix |
|---------|-----|
| FMT-001 | Add field with sensible default, flag for review |
| FMT-002 | Update `name` to match directory |
| FMT-003 | Remove quotes from description |
| FMT-005 | Reorder frontmatter to canonical order |
| SEC-001 | Insert stub section with `[TBD]` at correct position |
| SEC-002 | Reorder sections, preserving content |
| NAM-001 | Rename directory to match `name` |
| NAM-002 | Rename directory, hyphens replacing underscores |
| GOT-004 | Insert `### 0. Read Gotchas` step at start of Process |
