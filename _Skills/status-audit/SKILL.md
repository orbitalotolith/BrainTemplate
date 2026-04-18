---
name: status-audit
description: Audit _Status.md and _ActiveSessions/ content for freshness — stale decisions, resolved gotchas, drift between status and session files
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Glob, Grep, Read, AskUserQuestion
---

# Status Audit

Audit `_Status.md` and `_ActiveSessions/` content for freshness — stale decisions, resolved gotchas, drift between status and session files.

**Scope boundary with `/folder-audit`:** `/folder-audit` checks that `_ActiveSessions/` directories and files **exist** (structural). This skill checks that their **content is fresh and accurate** (semantic).

## Overview

Audit `_Status.md` and `_ActiveSessions/` content for freshness — stale decisions, resolved gotchas, drift between status and session files.

Read-only — reports findings without modifying any files.

## Process

### 0. Read Gotchas

Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### Preamble

#### 0a. Pull Brain Git

Use the **Bash** tool to run:

```bash
BRAIN="${BRAIN_ROOT:-}"
if [ -z "$BRAIN" ]; then
  BRAIN=$(dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null)
fi
if [ -z "$BRAIN" ]; then
  echo "ERROR: Cannot locate Brain root. Run _setup.sh or set BRAIN_ROOT in your shell config."
  exit 1
fi
DEV="$HOME/Development"
cd "$BRAIN" && git pull --ff-only 2>&1
```

If pull fails, use **AskUserQuestion** to warn the user and ask whether to proceed with potentially stale vault state.

#### 0b. Build Project Registry

Use the **Grep** tool to read the project registry from `$BRAIN/_projects.conf` (single source of truth for all project mappings):

```bash
grep -v '^#' "$BRAIN/_projects.conf" | grep -v '^$'
```

This produces `SLUG|CATEGORY|CODE_PATH` triples. All subsequent audits scope to these projects.

#### 0e. Initialize Findings

Create an empty findings list. Each finding will have:
- **ID:** `STA-<NUMBER>` (e.g., `STA-001`)
- **Severity:** HIGH, MEDIUM, LOW
- **Description:** What's wrong
- **Recommended action:** What to do about it

### Audit: Status & Session Freshness (STA-)

**Goal:** `_Status.md` files reflect current reality. Active Decisions are actually active. Gotchas are actually gotchas. `_ActiveSessions/` files are current and structurally sound.

**Read:**

Use the **Glob** tool to find all relevant files:

- All `_Status.md` files: find them via `$BRAIN/_ActiveSessions/*/_Status.md`
- All `$BRAIN/_ActiveSessions/*/session.md` files (top level only, not `_Parked/`)
- All `$BRAIN/_ActiveSessions/_Parked/*/session.md` files

#### Evaluate _Status.md

| If... | Then... | ID |
|-------|---------|-----|
| Active Decisions count >10 | Recommend promoting settled decisions to project CLAUDE.md, trim to ~10 | STA-BLOAT |
| A "decision" reads as architecture documentation, not an active choice | Recommend moving to CLAUDE.md or Architecture docs | STA-BLOAT |
| A Gotcha has been resolved (cross-ref DevLog "Problems & Solutions") | Recommend removal | STA-RESOLVED |
| Current Focus diverges from `_ActiveSessions/<slug>/session.md` handoff for same project | One of them is stale — flag | STA-STALE |
| `_ActiveSessions/<slug>/session.md` references a project in a state it's moved past | Handoff is stale | STA-SESSION |

#### Evaluate _ActiveSessions

| If... | Then... | ID |
|-------|---------|-----|
| Project in `_projects.conf` has no `<slug>/session.md` (active or parked) | Missing AS file — recommend creation from template | STA-MISSING-AS |
| AS file has empty or placeholder Handoff section ("No handoff recorded") for >7 days | Stale AS — should be refreshed or parked | STA-EMPTY-AS |
| AS file `updated:` date is >14 days old and project has recent DevLog entries | AS file not being maintained by `/save-session` | STA-DRIFT |
| AS file in `_ActiveSessions/` but `_Status.md` has `status: archived` | Should be in `_Parked/` | STA-PARK |
| AS file in `_Parked/` but `_Status.md` has `status: active` | Should be unparked | STA-UNPARK |

## Output

```
=== Status Audit Report ===
Date: YYYY-MM-DD
Projects scanned: [list]

Findings: N (HIGH: X, MEDIUM: Y, LOW: Z)

## HIGH
[STA-NNN] Description
  → Recommended action

## MEDIUM
...

## LOW
...
```

If zero findings: "No findings. Vault is clean for this area."

## Rules

**Severity Definitions:**

| Level | Meaning |
|-------|---------|
| HIGH | Actively wrong, duplicated, or causing confusion |
| MEDIUM | Stale or missing but not breaking anything |
| LOW | Cosmetic, informational, or acceptable for project phase |

- This skill is read-only — it reports findings but does not modify any files.
- Honest assessment — if everything is current and well-placed, say so. Don't invent findings to justify the audit.
