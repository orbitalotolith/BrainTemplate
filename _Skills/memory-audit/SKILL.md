---
name: memory-audit
description: Evaluate memory scope, deduplication, quality, and absorption — bidirectional analysis of project↔brain memory placement
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Glob, Grep, Read, AskUserQuestion
---

# Memory Audit

Bidirectional evaluation of memory scope, deduplication, quality, and absorption across all project and brain memory directories. Ensures every memory lives in exactly the right scope — global knowledge in `_Memory/brain/`, project-specific knowledge in project directories.

Memory is persistence tier 4 in the Brain vault. `/save-session` captures in-session. `/memory-audit` reviews placement and quality across sessions.

## Overview

Bidirectional evaluation of memory scope, deduplication, quality, and absorption across all project and brain memory directories. Ensures every memory lives in exactly the right scope — global knowledge in `_Memory/brain/`, project-specific knowledge in project directories.

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

#### 0d. Read Target Systems (for Memory Absorption)

Read all potential absorption targets upfront so MEM-ABSORB proposals are precise:

**Always read:**
- `~/.claude/CLAUDE.md` (global instructions)
- All `SKILL.md` files: `$BRAIN/_Skills/*/SKILL.md`
- `$BRAIN/_HowThisWorks.md`
- `$BRAIN/_KnowledgeBase/*.md` (all KB entries)
- Config files: `$BRAIN/_projects.conf`, `$BRAIN/_sync.conf`

**Read if in a project context** (CWD is inside a project with its own `CLAUDE.md`):
- Project `CLAUDE.md`

After reading, build a mental map: for each memory, note which target(s) are potentially relevant based on content overlap.

#### 0e. Initialize Findings

Create an empty findings list. Each finding will have:
- **ID:** `MEM-<NUMBER>` (e.g., `MEM-001`)
- **Severity:** HIGH, MEDIUM, LOW
- **Description:** What's wrong
- **Recommended action:** What to do about it

### Audit: Memory Evaluation — Bidirectional (MEM-)

**Goal:** Every memory lives in exactly the right scope. Global knowledge in `_Memory/brain/`, project-specific knowledge in project directories. No duplicates, no orphans, no misplacements.

Use the **Glob** tool to find files to read:
- All files in every `$BRAIN/_Memory/*/` directory
- Each directory's `MEMORY.md` index
- Also check live Claude memory at `~/.claude/projects/*/memory/` for files not yet synced to Brain

**Memory Type Heuristics:**

Each memory type has a natural absorption pattern — use as starting assumptions, not hard rules:

| Type | Natural tendency | Typical target |
|------|-----------------|----------------|
| **feedback** | Absorb or redundant | **Content determines target, not type label.** Behavioral rules → Skills or CLAUDE.md. Technical facts/gotchas → KnowledgeBase. |
| **reference** | Absorb or redundant | KnowledgeBase (technical patterns), configs (setup details) |
| **project** | Delete or keep | Temporal — delete when reflected in codebase. Keep only if the *why* is still load-bearing. |
| **user** | Keep | Identity/profile context. Absorb only if a skill explicitly needs to adapt to user context. |

A memory's `type` field reflects *how it was learned*. The *content* determines where it belongs. Always classify by content, not by type label.

#### Direction 1 — Project to Brain (promotion)

For each memory in a non-brain project directory, evaluate: is this actually global?

| Memory type | Likely scope | Example |
|-------------|-------------|---------|
| `feedback` about Claude's behavior | Global → promote | "fix root causes, not symptoms" |
| `user` about skills/preferences | Global → promote | "user prefers private repos" |
| `feedback` about a specific tool/workflow | Global if tool-agnostic → promote | "no bandaid fixes" |
| `project` about a specific codebase | Project → stays | "ML pipeline uses two stages" |
| `reference` to project-specific resource | Project → stays | "Google Drive via rclone" |
| `reference` to general tool/platform | Global → promote | — |
| `feedback` about client-specific constraint | Project → stays | "no Docker for Mercana" |

If global: → **MEM-PROMOTE** (recommend move to `$BRAIN/_Memory/brain/`, update both MEMORY.md indexes, remove from project directory)

#### Direction 2 — Brain to Project (demotion)

For each memory in `_Memory/brain/`, evaluate: is this actually project-specific?

| If... | Then... |
|-------|---------|
| Memory only applies to one project's context | **MEM-DEMOTE** — recommend move to that project's directory |
| Memory references a client-specific constraint | **MEM-DEMOTE** — recommend move to client project |
| Memory is truly global | No finding — stays in brain |

#### Deduplication

| If... | Then... | ID |
|-------|---------|-----|
| Identical or near-identical files exist in multiple directories | Recommend keeping authoritative copy, removing duplicate | MEM-DUPE |
| Memory content is fully captured in `_Profile/` or `_KnowledgeBase/` | Candidate for removal — knowledge is preserved elsewhere | MEM-REDUNDANT |

#### Quality — Root Cause Check

Memories should capture principles, not patches. For each `feedback` type memory, evaluate:

| If... | Then... | ID |
|-------|---------|-----|
| Memory addresses one specific instance rather than the class of problem | Recommend rewrite to capture the general principle | MEM-BANDAID |
| Memory says "don't do X" without explaining why or when | Recommend adding **Why:** and **How to apply:** lines | MEM-SHALLOW |
| Multiple memories cover closely related feedback (e.g., 3 memories about testing approaches) | Recommend combining into one authoritative memory | MEM-COMBINE |

**MEM-BANDAID example:** "Don't use port 5001 for ML service" is a band-aid. The root cause memory is: "Check for port conflicts with macOS services before choosing dev ports. macOS AirPlay uses 5000, ControlCenter uses 5001." The fix addresses the class of problem, not the instance.

**MEM-COMBINE criteria:** If two or more memories in the same directory share the same underlying principle or could be expressed as a single coherent rule, combine them. Prefer fewer, richer memories over many thin ones. Update the MEMORY.md index to reflect the consolidated file.

#### Absorption

For each remaining memory after dedup/quality checks, cross-reference its discrete facts against target systems (Skills, CLAUDE.md, KB, configs — read in step 0d). This catches memories whose lessons can be graduated into permanent systems:

| If... | Then... | ID |
|-------|---------|-----|
| Memory's lesson can be baked into a skill rule, CLAUDE.md section, or KB entry | Recommend absorption with exact diff showing the target edit | MEM-ABSORB |
| Memory's content is already fully captured in one or more targets | Candidate for deletion — knowledge preserved elsewhere | MEM-REDUNDANT |
| Memory is partially covered — some facts exist in targets, some don't | MEM-ABSORB for the gap, note what's already covered | MEM-ABSORB |

**Target freshness rule:** If proposing multiple absorptions to the same target file, note the dependency — each edit changes the target.

#### Housekeeping

| If... | Then... | ID |
|-------|---------|-----|
| `MEMORY.md` index doesn't match actual files in directory | Recommend updating the index | MEM-INDEX |
| `project` memory references superseded state | Flag for removal | MEM-STALE |
| Memory content is a technical gotcha/platform quirk | Better as KB entry than memory | MEM-RECLASSIFY |

## Output

```
=== Memory Audit Report ===
Date: YYYY-MM-DD
Projects scanned: [list]

Findings: N (HIGH: X, MEDIUM: Y, LOW: Z)

## HIGH
[MEM-NNN] Description
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
- Bidirectional evaluation — memories flow both ways: project to brain AND brain to project.
- One home per fact — if information lives in multiple places, that's a finding.
- Prune aggressively — stale entries are worse than missing entries.
- When evaluating memories, read the content — don't judge by filename or type alone.
- A memory can be globally useful even if it was created in a project context.
