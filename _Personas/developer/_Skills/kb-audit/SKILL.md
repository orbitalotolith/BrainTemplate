---
name: kb-audit
description: Audit _KnowledgeBase/ entries for freshness, version context, format compliance, and scope correctness
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Glob, Grep, Read, AskUserQuestion
---

# KB Audit

Audit `_KnowledgeBase/` entries for freshness, version context, format compliance, and scope correctness. Ensures every KB entry is current, properly formatted, and tagged so staleness can be judged.

KB rules from CLAUDE.md: entries must have frontmatter `tags: [reference, <domain>]`, topic heading, Gotchas list with version/context ("as of Xcode 16") for staleness judgment. Domains: ble, ios, macos, tauri, rust, security, xcode, swift, etc.

## Overview

Audit `_KnowledgeBase/` entries for freshness, version context, format compliance, and scope correctness. Ensures every KB entry is current, properly formatted, and tagged so staleness can be judged.

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
cd "$BRAIN" && git pull --ff-only 2>&1
```

If pull fails, warn the user and use **AskUserQuestion** to ask whether to proceed with potentially stale vault state.

#### 0e. Initialize Findings

Create an empty findings list. Each finding will have:
- **ID:** `KBF-<NUMBER>` (e.g., `KBF-001`)
- **Severity:** HIGH, MEDIUM, LOW
- **Description:** What's wrong
- **Recommended action:** What to do about it

### Audit: Knowledge Base Freshness (KBF-)

**Goal:** Every KB entry is current, properly formatted, and tagged with version context so staleness can be judged.

Use the **Glob** tool to find files, then read each: `$BRAIN/_KnowledgeBase/*.md`

**Evaluate each entry/bullet:**

| If... | Then... | ID |
|-------|---------|-----|
| Entry has no version context (no "as of X", no version tag) | Can't judge staleness — flag | KBF-VERSION |
| Entry references a version 2+ major versions behind current | May be outdated — flag for review | KBF-STALE |
| File missing `tags: [reference, <domain>]` frontmatter | Format violation | KBF-FORMAT |
| Entry duplicates content in another KB file | Redundant — recommend consolidation | KBF-DUPE |
| Entry is project-specific (belongs in _Status.md Gotchas or CLAUDE.md) | Misplaced — flag for move | KBF-SCOPE |

**Format reference:** Each KB file should have:
- Frontmatter: `tags: [reference, <domain>]`
- Topic heading
- Sections with entries
- Gotchas list where each entry includes version/context

## Output

```
=== KB Audit Report ===
Date: YYYY-MM-DD

Findings: N (HIGH: X, MEDIUM: Y, LOW: Z)

## HIGH
[KBF-NNN] Description
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
