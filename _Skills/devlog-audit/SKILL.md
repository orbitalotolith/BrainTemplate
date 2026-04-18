---
name: devlog-audit
description: Audit _DevLog/ entries for content quality, size, template compliance, and unpromoted knowledge
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Glob, Grep, Read, AskUserQuestion
---

# DevLog Audit

Audit `_DevLog/` entries for content quality, size, template compliance, and unpromoted knowledge. Covers both vault-level DevLogs (`_DevLog/*.md` for Brain infrastructure work) and project-level DevLogs (`_DevLog/<slug>/` per-project subdirectories).

## Overview

Audit `_DevLog/` entries for content quality, size, template compliance, and unpromoted knowledge. Covers both vault-level DevLogs (`_DevLog/*.md` for Brain infrastructure work) and project-level DevLogs (`_DevLog/<slug>/` per-project subdirectories).

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

If pull fails, warn the user and use **AskUserQuestion** to ask whether to proceed with potentially stale vault state.

#### 0b. Build Project Registry

Read the project registry from `$BRAIN/_projects.conf` (single source of truth for all project mappings). Use the **Grep** tool to search:

```bash
grep -v '^#' "$BRAIN/_projects.conf" | grep -v '^$'
```

This produces `SLUG|CATEGORY|CODE_PATH` triples. Used to enumerate per-slug DevLog directories.

#### 0e. Initialize Findings

Create an empty findings list. Each finding will have:
- **ID:** `DLG-<NUMBER>` (e.g., `DLG-001`)
- **Severity:** HIGH, MEDIUM, LOW
- **Description:** What's wrong
- **Recommended action:** What to do about it

### Audit: DevLog Maintenance (DLG-)

**Goal:** DevLog entries are concise, well-structured, and not redundant. Knowledge that should have been promoted elsewhere is identified.

Use the **Glob** tool to find files, then read each:
- `$BRAIN/_DevLog/*.md` (vault-level — Brain infrastructure work only)
- All `$BRAIN/_DevLog/*/` (project-level, per-slug subdirectories)

#### Content Quality (all DevLogs)

| If... | Then... | ID |
|-------|---------|-----|
| Entry is >10KB (~200 lines) | Candidate for consolidation — trim verbose sections, keep decisions + understanding | DLG-SIZE |
| Entry has empty or placeholder sections (e.g., `## Problems & Solutions` with nothing under it) | Remove empty headings or fill them | DLG-INCOMPLETE |
| Entry is a raw session dump without template structure | Should follow template: Session Goal, What Got Done, Decisions, Problems & Solutions, Understanding Gained | DLG-FORMAT |
| Decisions or Understanding sections contain knowledge not in `_Status.md` or KB | Unpromoted — should be extracted | DLG-UNPROMOTED |

#### Cross-Level Dedup

| If... | Then... | ID |
|-------|---------|-----|
| Same content in vault-level AND project-level DevLog | Consolidate to project level (vault DevLog is for Brain infrastructure only) | DLG-DUPE |

## Output

```
=== DevLog Audit Report ===
Date: YYYY-MM-DD
Projects scanned: [list]

Findings: N (HIGH: X, MEDIUM: Y, LOW: Z)

## HIGH
[DLG-NNN] Description
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
- Prune aggressively — stale entries are worse than missing entries.
