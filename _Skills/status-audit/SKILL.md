---
name: status-audit
description: Audit _Status.md and _ActiveSessions/ content for freshness — surface stale/bloated/undated/resolvable entries, recommend routing destinations, cross-ref with DevLog for context
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Glob, Grep, Read, AskUserQuestion
---

# Status Audit

Audit `_Status.md` and `_ActiveSessions/` content for freshness — surface stale/bloated/undated/resolvable entries, recommend routing destinations, cross-ref with DevLog for context.

**Scope boundary with `/folder-audit`:** `/folder-audit` checks that `_ActiveSessions/` directories and files **exist** (structural). This skill checks that their **content is fresh and accurate** (semantic).

## Overview

Find bloat, staleness, and mis-placement in `_Status.md` files. Produce an informational findings report that surfaces each candidate with DevLog context so the user can make keep/archive/route decisions.

Read-only — reports findings without modifying any files. Cleanup happens when the user acts on the findings (typically by asking Claude to apply them one-by-one).

## Caps enforced

| Section | Max | Rule |
|---------|-----|------|
| Active Decisions | 25 | Each entry must have `(YYYY-MM-DD)` date |
| Gotchas | 10 | Each entry must have `(YYYY-MM-DD)` date; only "still biting" items — resolved ones belong in archive or routed destination |
| Recent Sessions | 5 | Already auto-pruned by `/save-lightweight` |

## Routing chart (for Gotchas)

When a Gotcha is flagged as candidate-for-routing, audit recommends a destination:

| Nature of gotcha | Target |
|------------------|--------|
| Platform / framework / tool quirk (cross-project applicable) | `_KnowledgeBase/<domain>.md` |
| Settled project convention new code must follow (short, load-bearing) | `_ClaudeSettings/<slug>/CLAUDE.md` Key Conventions |
| Project architecture / design pattern with rationale (longer, "why we chose X over Y") | `_DevLog/<slug>/architecture.md` (optional, not auto-loaded) |
| A bug we can fix in our code | "Fix in code" (audit names it; user fixes via normal dev flow) |
| A skill failure mode or edge case | `_Skills/<skill>/SKILL.md` or `gotchas.md` |
| AI behavior rule or user preference | `_Memory/<slug>/` or `_Memory/brain/` |
| In-flight concern — resolves when current work ships | Keep in `_Status.md` (this is the only case) |

For Active Decisions, the destinations are:

| Nature of decision | Target |
|------------------|--------|
| Still in flight — could still change | Keep in `_Status.md` (dated `(YYYY-MM-DD)`) |
| Settled convention new code must follow (short) | `_ClaudeSettings/<slug>/CLAUDE.md` Key Conventions |
| Architectural choice with rationale worth preserving | `_DevLog/<slug>/architecture.md` (optional, not auto-loaded) |
| Code-derivable ("what the code does") — delete, don't document | *(no target — delete outright)* |
| Superseded by a later decision | Archive to `_DevLog/<slug>/archive.md` |

**Token cost consideration:** `CLAUDE.md` loads every session, so it should hold only short must-know invariants. Longer decisions with rationale go to `_DevLog/<slug>/architecture.md`, which is not auto-loaded — consult on demand when touching the related area.

## Archive format

When a finding recommends archiving a Decision or Gotcha, the recommendation includes the archive-line format preserving both dates:

```
(<original-date> → archived YYYY-MM-DD) <original entry text>
```

This goes into `_DevLog/<slug>/archive.md` under a `## Decisions` or `## Gotchas` section.

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

This produces `SLUG|CATEGORY|CODE_PATH|COLLAB` rows. All subsequent audits scope to these projects.

#### 0d. Read Recent DevLog Context

For each project, read the most recent 60 days of DevLog entries (used for cross-referencing whether a Decision or Gotcha has been mentioned recently — adds context to findings).

```bash
find "$BRAIN/_DevLog/<slug>/" -name "*.md" -mtime -60 -type f 2>/dev/null | sort
```

This is informational — it populates a per-project "recently mentioned" set of terms that help the user decide during cleanup. Do NOT auto-classify decisions as stale based on DevLog mentions; just surface the context.

#### 0e. Initialize Findings

Create an empty findings list. Each finding will have:
- **ID:** `STA-<NUMBER>` (e.g., `STA-001`)
- **Severity:** HIGH, MEDIUM, LOW
- **Description:** What's wrong (include the full entry text for Decisions/Gotchas)
- **DevLog context:** Recent mentions (if any) from last 60 days — 1-2 line summary
- **Recommended action:** What to do about it (including target destination and archive format when relevant)

### Audit: Status & Session Freshness (STA-)

**Goal:** `_Status.md` files reflect current reality. Active Decisions are actually active. Gotchas are actually gotchas. `_ActiveSessions/` files are current and structurally sound.

**Read:**

Use the **Glob** tool to find all relevant files:

- All `_Status.md` files via `$BRAIN/_ActiveSessions/*/_Status.md`
- All `$BRAIN/_ActiveSessions/*/session.md` files (top level only, not `_Parked/`)
- All `$BRAIN/_ActiveSessions/_Parked/*/session.md` files

#### Evaluate _Status.md — per-entry checks

For each Active Decision and Gotcha entry, check these in order:

| If... | Then... | ID | Severity |
|-------|---------|-----|----------|
| Entry has no `(YYYY-MM-DD)` date tag | Recommend adding a date or archiving. Include full entry text in finding. | STA-UNDATED | MEDIUM |
| Gotcha is explicitly mentioned as FIXED/RESOLVED in recent DevLog "Problems & Solutions" | Recommend removal from _Status.md, archive to `_DevLog/<slug>/archive.md` under `## Gotchas`. Include the DevLog citation. | STA-RESOLVED | HIGH |
| Gotcha matches a routing-chart category (platform quirk, project convention, skill failure, etc.) | Recommend routing: name the target file/location + show what the target edit would look like | STA-ROUTE | MEDIUM |
| Decision reads as static architecture documentation (not an active choice that could change) | Recommend moving to `_ClaudeSettings/<slug>/CLAUDE.md` Key Conventions | STA-DOC | MEDIUM |
| Decision explicitly contradicts or supersedes a later-dated decision in the same list | Recommend archiving the superseded one | STA-SUPERSEDED | HIGH |

#### Evaluate _Status.md — section-level checks

| If... | Then... | ID | Severity |
|-------|---------|-----|----------|
| Active Decisions count > 25 | Report total count, list all entries, invite user to archive per-entry. Do NOT auto-classify. Each listed entry includes its DevLog context (last 60 days mentions). | STA-DECISIONS-OVERCAP | MEDIUM |
| Gotchas count > 10 | Same treatment — list all with DevLog context, user decides per entry. | STA-GOTCHAS-OVERCAP | MEDIUM |
| `Current Focus` diverges from `session.md` handoff for same project | One of them is stale — flag for reconciliation | STA-DRIFT | HIGH |
| `Recent Sessions` has more than 5 entries (should be auto-pruned) | `/save-lightweight` not running or not pruning | STA-RECENT-BLOAT | LOW |

#### Evaluate _ActiveSessions structure

| If... | Then... | ID | Severity |
|-------|---------|-----|----------|
| Project in `_projects.conf` has no `<slug>/session.md` (active or parked) | Missing AS file — recommend creation from template | STA-MISSING-AS | HIGH |
| AS file has empty or placeholder Handoff section ("No handoff recorded") for >7 days | Stale AS — should be refreshed or parked | STA-EMPTY-AS | MEDIUM |
| AS file `updated:` date is >14 days old and project has recent DevLog entries | AS file not being maintained by `/save-session` | STA-AS-DRIFT | MEDIUM |
| AS file in `_ActiveSessions/` but `_Status.md` has `status: archived` | Should be in `_Parked/` | STA-PARK | LOW |
| AS file in `_Parked/` but `_Status.md` has `status: active` | Should be unparked | STA-UNPARK | LOW |

## Output

```
=== Status Audit Report ===
Date: YYYY-MM-DD
Projects scanned: [list]

Findings: N (HIGH: X, MEDIUM: Y, LOW: Z)

## HIGH
[STA-NNN] <slug> — Description
  Entry: "<full entry text if Decision/Gotcha>"
  Date: (YYYY-MM-DD) or "undated"
  DevLog context: <summary of recent mentions or "no recent mentions">
  → Recommended action: <specific action, target file, archive format>

## MEDIUM
...

## LOW
...

---
Cleanup: to act on these findings, ask Claude: "apply the status-audit findings"
(Claude will walk through each interactively with preview-then-confirm.)
```

If zero findings: "No findings. _Status.md files are clean for all projects."

## Rules

**Severity Definitions:**

| Level | Meaning |
|-------|---------|
| HIGH | Actively wrong — drift between files, resolved gotchas still in active list, explicitly superseded decisions |
| MEDIUM | Stale or over-cap but not breaking anything |
| LOW | Cosmetic, informational, or acceptable for project phase |

- This skill is **read-only** — reports findings but does not modify any files.
- Honest assessment — if everything is current and well-placed, say so. Don't invent findings to justify the audit.
- Do NOT auto-classify Active Decisions as "no longer active." The user owns that call. Audit surfaces entries over the cap plus DevLog context so the user can decide.
- For Gotchas with clear routing targets, recommend the target precisely (file path, section, proposed insertion text) so the follow-up "apply findings" step is fast.
- Per-entry findings (STA-UNDATED, STA-RESOLVED, STA-ROUTE, STA-DOC, STA-SUPERSEDED) always include the **full entry text** in the Description — the user shouldn't need to open `_Status.md` to review.
- When archiving is recommended, always use the format `(<original-date> → archived <today>) <original text>` preserving both dates. Target: `_DevLog/<slug>/archive.md` under `## Decisions` or `## Gotchas` heading (create the file and heading if missing — recommendation only, this skill does not write).
