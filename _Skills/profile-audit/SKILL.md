---
name: profile-audit
description: Audit _Profile/ subfiles against user-type memories — flags gaps, staleness, and stale memory references
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Glob, Grep, Read, AskUserQuestion
---

# Profile Audit

Audit `_Profile/` subfiles against user-type memories across all project memory directories. Flags gaps, staleness, and stale memory references.

`/save-session` captures in-session learnings. `/profile-audit` reviews whether those learnings have been properly reflected in Profile subfiles across sessions. Run periodically or after heavy sessions.

## Overview

Audit `_Profile/` subfiles against user-type memories across all project memory directories. Flags gaps, staleness, and stale memory references.

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

This produces `SLUG|CATEGORY|CODE_PATH` triples. All subsequent audits scope to these projects.

#### 0e. Initialize Findings

Create an empty findings list. Each finding will have:
- **ID:** `PRF-<NUMBER>` (e.g., `PRF-001`)
- **Severity:** HIGH, MEDIUM, LOW
- **Description:** What's wrong
- **Recommended action:** What to do about it

### Audit: Profile Freshness (PRF-)

**Goal:** Ensure `_Profile/` is current and complete — the authoritative record of who the user is.

Use the **Glob** tool to find files, then read each:
- All memory files with `type: user` frontmatter across ALL project memory directories: `~/.claude/projects/*/memory/` (not just `_Memory/` — check the live Claude memory, which may be newer)
- All `$BRAIN/_Profile/*.md` files (index.md, identity.md, business.md, skills.md, preferences.md)

**Evaluate:**

For each `user` type memory, extract factual claims and check against Profile subfiles:

| If... | Then... | ID |
|-------|---------|-----|
| Memory contains facts not in any Profile subfile | Flag — propose addition to correct subfile | PRF-GAP |
| Profile contains info contradicted by newer memory | Flag — propose update | PRF-STALE |
| Profile `updated:` date is >30 days old | Flag for manual review | PRF-REVIEW |
| Memory file has stale references (old paths, old file names) | Flag the memory file | PRF-MEMORY |
| Profile already captures the information accurately | No finding — skip | — |

**Subfile routing:** Match new facts to the right Profile subfile:
- Skills, tools, platforms, hardware → `skills.md`
- Business state, clients, revenue, services → `business.md`
- Identity, education, philosophy, background → `identity.md`
- How they work with AI, communication style, dev patterns → `preferences.md`

## Output

```
=== Profile Audit Report ===
Date: YYYY-MM-DD
Projects scanned: [list]

Findings: N (HIGH: X, MEDIUM: Y, LOW: Z)

## HIGH
[PRF-NNN] Description
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
- When evaluating memories, read the content — don't judge by filename or type alone.
