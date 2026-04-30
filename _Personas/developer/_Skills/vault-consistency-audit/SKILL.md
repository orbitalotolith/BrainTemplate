---
name: vault-consistency-audit
description: Audit cross-project consistency — CLAUDE.md completeness, _projects.conf drift, symlink integrity, and _HowThisWorks.md documentation drift
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Glob, Grep, Read, AskUserQuestion
---

# Vault Consistency Audit

Audit cross-project consistency — CLAUDE.md completeness, `_projects.conf` drift, symlink integrity, and `_HowThisWorks.md` documentation drift.

**Scope boundaries:** `/folder-audit` checks that vault directories and files **exist** (structural existence). `/structure-audit` checks code repo internal layout (Universal Project Structure). This skill checks vault-level **cross-project consistency** and **documentation-vs-reality** drift.

## Overview

Audit cross-project consistency — CLAUDE.md completeness, `_projects.conf` drift, symlink integrity, and `_HowThisWorks.md` documentation drift.

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

#### 0c. Read Structural Reference

Read `$BRAIN/_HowThisWorks.md` for naming conventions and symlink architecture. This is the documentation-vs-reality baseline for XPC-DOCRIFT checks.

#### 0e. Initialize Findings

Create an empty findings list. Each finding will have:
- **ID:** `XPC-<NUMBER>` (e.g., `XPC-001`)
- **Severity:** HIGH, MEDIUM, LOW
- **Description:** What's wrong
- **Recommended action:** What to do about it

### Audit: Cross-Project Consistency (XPC-)

**Goal:** All projects follow vault conventions. No structural gaps, no stale paths, no configuration drift. All symlinks valid — both forward (code→notes) and reverse (notes→CLAUDE.md).

**Read:**
- Project CLAUDE.md files (via `_ClaudeSettings/<slug>/CLAUDE.md` symlinks)
- `$BRAIN/_projects.conf` (the single source of truth for project registry)
- Symlink state for each registered project

#### Project CLAUDE.md Evaluation

| If... | Then... | ID |
|-------|---------|-----|
| Project CLAUDE.md has stale vault paths (e.g., pre-restructure references) | Flag with specific stale lines | XPC-CLAUDE |
| Project CLAUDE.md missing `## Project Structure` (blocks structure detection) | Flag | XPC-CLAUDE |
| `_Memory/` subdir exists but slug not in `_projects.conf` (or vice versa) | Registry drift | XPC-MAP |
| Project directory exists in `$BRAIN/_Workbench/` but not registered in `$BRAIN/_projects.conf` | Orphaned project | XPC-ORPHAN |
| Project missing standard infrastructure (DevLog/ dir, _Status.md) | Flag as LOW (acceptable for planning-phase projects) | XPC-STRUCTURE |

#### Documentation vs Reality Divergence

Cross-check `_HowThisWorks.md` prose descriptions against actual filesystem implementation. Conventions described in documentation should match what's actually happening on disk.

| If... | Then... | ID |
|-------|---------|-----|
| `_HowThisWorks.md` describes a convention but actual implementation differs | Documentation is stale — flag specific section and what changed | XPC-DOCRIFT |
| `_HowThisWorks.md` Folder Layout lists a directory that doesn't exist (or misses one that does) | Structure drift — flag | XPC-DOCRIFT |
| `_HowThisWorks.md` describes `_projects.conf` format that doesn't match actual file column count/fields | Config format drift — flag | XPC-DOCRIFT |

**XPC-DOCRIFT check procedure:**
1. Read `_HowThisWorks.md` Folder Layout section — extract expected directory names
2. Use the **Glob** tool to compare against `$BRAIN/_*/` directories
3. Read `_HowThisWorks.md` sections describing conventions (memory management, symlink architecture, config format)
4. Spot-check each convention against reality (e.g., are memory directories actually symlinks or copies? Does `_projects.conf` actually have the described columns?)
5. Flag each divergence with the specific `_HowThisWorks.md` section and the actual state

If divergence found, recommend updating `_HowThisWorks.md` — reality wins unless the doc describes an intended-but-not-yet-implemented state.

#### Symlink Integrity

For each project in `_projects.conf` where code repo is cloned:

| If... | Then... | ID |
|-------|---------|-----|
| `<code_repo>/project_files/brain` symlink missing or broken | Forward symlink needs repair — run `_setup.sh` | XPC-SYMLINK |
| `<code_repo>/project_files/brain` points to wrong target | Symlink target mismatch | XPC-SYMLINK |

**Symlink check procedure:**
```bash
# For each project with CODE_PATH in _projects.conf:
CODE="$DEV/$CODE_PATH"

# Forward check: code repo project_files/brain/ is a real directory
if [ -d "$CODE" ]; then
  LINK="$CODE/project_files/brain"
  if [ -L "$LINK" ]; then
    # Old format — SHR-001 (symlink should be a real directory)
  elif [ -d "$LINK" ]; then
    # Correct — real directory
  elif [ ! -e "$LINK" ]; then
    # Missing project_files/brain/
  fi
fi
```

## Output

```
=== Vault Consistency Audit Report ===
Date: YYYY-MM-DD
Projects scanned: [list]

Findings: N (HIGH: X, MEDIUM: Y, LOW: Z)

## HIGH
[XPC-NNN] Description
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
