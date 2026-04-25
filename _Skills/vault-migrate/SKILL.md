---
name: vault-migrate
description: Analyze structural differences between local vault and BrainShared (or after local changes), ask clarifying questions, and generate a superpowers-compatible migration plan. Use after pulling BrainShared with big changes, or before pushing local structural changes.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Grep, Read, Write, AskUserQuestion, Skill
---

# Vault Migrate

## Overview

Analyze structural differences in the Brain vault and generate a phased migration plan. Works in two directions:

- **Post-pull:** After `/pull-brainshared` brings partner changes, analyze what changed and plan how to adapt the local vault
- **Pre-push / post-local-change:** After local structural changes, verify consistency and plan propagation before pushing to BrainShared

This skill does **analysis and planning**. It produces a superpowers-compatible migration plan saved to `_Docs/brain/Plans/`. Execution happens via `superpowers:executing-plans` or `superpowers:subagent-driven-development`.

**Relationship to other skills:**
- `/pull-brainshared` syncs shared files → `/vault-migrate` analyzes the structural impact
- `/brain-check` validates symlinks and runs health checks (fast, structural)
- `/folder-audit` audits completeness and naming conventions (thorough, structural)
- Content audit skills (`/profile-audit`, `/memory-audit`, `/kb-audit`, `/devlog-audit`, `/status-audit`, `/vault-consistency-audit`) maintain content quality
- `/vault-migrate` fills the gap none of these cover: understanding *what changed structurally* and *what needs to happen* to complete the migration

## Arguments

| Argument | Effect |
|----------|--------|
| *(none)* | Auto-detect: diff local vault against BrainShared and filesystem references |
| `--post-pull` | Explicitly analyze after BrainShared pull (default if BrainShared has newer commits than last pull) |
| `--pre-push` | Verify local vault consistency before pushing to BrainShared |
| `--local` | Analyze local changes only (no BrainShared comparison) |
| `OLD NEW [OLD2 NEW2 ...]` | Also include explicit rename mappings (merged with auto-detected changes) |

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory before proceeding.

### Phase 0: Setup

#### 0a. Detect Brain Root

Use the **Bash** tool to run:

```bash
BRAIN="${BRAIN_ROOT:-}"
if [ -z "$BRAIN" ]; then
  BRAIN=$(dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null)
fi
if [ -z "$BRAIN" ]; then
  echo "ERROR: Cannot locate Brain root. Set BRAIN_ROOT in your shell config."
  exit 1
fi
```

#### 0b. Read Structural References

Read these files to understand the expected vault structure:
- `$BRAIN/_HowThisWorks.md` — canonical structural reference (Folder Layout section)
- `$BRAIN/_projects.conf` — project registry (slug, category, code path, collab flag)
- `$BRAIN/_setup.sh` — what the setup script creates (symlinks, directories)
- `$BRAIN/_health-check.sh` — what validation expects

Extract from each:
- Expected directory names and hierarchy
- Expected symlink targets
- Expected config format (column count, field names)
- Expected per-project structure (session files, status files, CLAUDE.md locations)

#### 0c. Determine Mode

Parse arguments to determine mode:
- If `--pre-push`: set MODE=pre-push
- If `--post-pull`: set MODE=post-pull
- If `--local`: set MODE=local — diffs local vault against ALL structural references (`_HowThisWorks.md`, `_setup.sh`, `_health-check.sh`, `_projects.conf`). No BrainShared comparison. Surface all differences and let the user choose which to act on.
- If no flag: auto-detect by checking `_sync.conf` dates — if `LAST_PULL_DATE` is more recent than last vault-migrate run, default to post-pull; otherwise default to local

#### 0d. Read BrainShared State (post-pull and pre-push modes)

If MODE is post-pull or pre-push:
- Clone BrainShared to a temp directory: `SHARED_TMP=$(mktemp -d /tmp/brainshared-migrate-$$)` using the remote from `_sync.conf` `SHARED_BRAIN_REMOTE`
- Read `$SHARED_TMP/` directory tree
- Read `$BRAIN/_sync.conf` for last sync timestamps and commit hashes
- If post-pull: the BrainShared content represents what partner pushed — this is the "target" state for shared files
- If pre-push: the BrainShared content represents what partner last saw — local changes are the "source" being validated

---

### Phase 1: Deep Diff

This phase identifies ALL structural differences, not just directory renames. Six diff categories:

#### 1a. Directory Structure Diff

Compare local vault directory tree against:
- `_HowThisWorks.md` expected layout (catches drift from documented structure)
- BrainShared directory tree (catches partner changes) — post-pull/pre-push modes only

Categorize each difference:
- **Renamed:** old dir missing + new dir with similar content exists
- **New:** directory exists in target but not locally (or vice versa for pre-push)
- **Deleted:** directory exists locally but not in target/docs
- **Reorganized:** files moved between directories (detect by content similarity)

#### 1b. File-Level Diff

For shared content (files that exist in BrainShared):
```bash
# Compare each shared file against local version
diff "$SHARED_TMP/<path>" "$BRAIN/<path>"
```

Categorize:
- **Content changed:** same file, different content (need to understand what changed)
- **Format changed:** same data, different structure (e.g., config column format)
- **New file:** exists in source but not target
- **Deleted file:** exists in target but not source

#### 1c. Config Format Diff

Specifically analyze structured config files:
- `_projects.conf` — compare column count, field order, field semantics
- `_sync.conf` / `_sync.conf.template` — compare field names and structure
- `_setup.sh` — compare the patterns used (symlink targets, directory creation, iteration style)

For each config change, describe the transformation needed (not just "file differs").

#### 1d. Symlink Convention Diff

Detect changes in how symlinks are structured:
- Per-project symlinks (e.g., `project_files/brain/` as directory of symlinks vs single symlink)
- Memory management (copy-based vs symlink-based)
- CLAUDE.md chain (where canonical files live, how repos discover them)

Check actual symlinks on disk:
```bash
# Check all symlinks under project_files/brain/ in code repos
for repo in $(awk -F'|' '{print $3}' "$BRAIN/_projects.conf" | grep -v '^$'); do
  if [ -d "$repo/project_files/brain" ]; then
    ls -la "$repo/project_files/brain/"
  fi
done
```

#### 1e. Script Logic Diff

If `_setup.sh` or `_health-check.sh` changed:
- Diff the scripts to understand behavioral changes (not just path references)
- Identify new directories/symlinks the scripts now create
- Identify removed conventions the scripts no longer enforce
- Identify changed iteration patterns (e.g., new _projects.conf format requires different parsing)

#### 1f. Rename Detection (Legacy)

The original vault-migrate logic — compare `_HowThisWorks.md` documented names against filesystem. This catches simple renames that the deeper diff might not flag explicitly. Merge any rename mappings from explicit arguments.

Collect ALL differences into a unified findings list with categories.

### Phase 1 Gate

If the findings list is empty (zero structural differences across all six diff categories), report that the vault is consistent with all structural references and exit. Do not proceed to Phase 2.

---

### Phase 2: Impact Analysis

For each finding from Phase 1, trace the full blast radius.

#### 2a. Reference Tracing

For each structural change, use the **Grep** tool to search the entire vault for affected references:

| Scope | Files | What to look for |
|-------|-------|-------------------|
| Documentation | `_HowThisWorks.md`, `key-to-dev.md` | Path references, convention descriptions |
| Global config | `_ClaudeSettings/global/CLAUDE.md` | Persistence tiers, workflow paths, structure detection |
| Scripts | `_setup.sh`, `_health-check.sh` | Path construction, symlink targets, validation logic |
| Skills | `_Skills/*/*.md` | Path references, tool calls, convention assumptions |
| Sync config | `_sync.conf`, `_sync.conf.template` | Field names, path patterns |
| Project registry | `_projects.conf` | Format assumptions, field references |
| Code repos | All repos from `_projects.conf` | `.gitignore`, `CLAUDE.md`, `project_files/` |
| Memory | `_Memory/*/` | Any path references in memory files |

Search for all path variants (bare name, `$BRAIN/` prefixed, `$BRAIN_ROOT/` prefixed, relative paths).

#### 2b. Dependency Ordering

Build a dependency graph of changes:
- Documentation updates must happen before consumer updates
- Config format changes must happen before script changes that parse the config
- Script changes must happen before symlink creation that depends on new script logic
- File moves must happen before reference updates that point to new locations
- Per-repo changes depend on having the new conventions established first

#### 2c. Breaking Change Detection

Flag changes that could break running systems:
- `_ActiveSessions` rename → CATASTROPHIC (Brain root detection). Suggest the user update their shell config to set `$BRAIN_ROOT` explicitly so detection no longer depends on this directory name.
- `project_files/brain` convention change → HIGH (all code repos affected)
- `_projects.conf` format change → HIGH (12+ skills parse this at runtime)
- `_setup.sh` logic change → HIGH (re-running setup with new logic on old structure)
- Symlink convention change → MEDIUM (broken symlinks until fixed)

For HIGH and CATASTROPHIC findings: these must be surfaced with explicit severity warnings in Phase 3 and require explicit user acknowledgment via AskUserQuestion before being included in the generated plan. Do not silently include breaking changes.

#### 2d. Per-Project Impact

Cross-reference `_projects.conf` to enumerate which projects are affected:
- Which slugs need file moves (session files, status files, CLAUDE.md)?
- Which code repos need `project_files/brain/` restructured?
- Which repos need `.gitignore` updates?
- Which memory directories need symlink changes?

List affected projects explicitly — migration plans must iterate all of them.

---

### Phase 3: Interactive Q&A

Present findings and ask clarifying questions before generating the plan. This phase uses AI reasoning to identify ambiguities and resolve them with the user.

#### 3a. Present Diff Summary

Show a categorized summary of all differences found:

```
## Structural Differences Found

### Directory Changes (N)
- [RENAMED] _Notes/ → (removed, content distributed to _ActiveSessions/, _DevLog/, _Workbench/)
- [NEW] _Workbench/ (exists in BrainShared, not locally)
- ...

### Config Changes (N)
- [FORMAT] _projects.conf: 3 columns → 4 columns (added COLLAB field)
- [REWRITE] _setup.sh: new symlink conventions, memory symlinks instead of copies
- ...

### Symlink Changes (N)
- [CONVENTION] project_files/brain: single symlink → directory of per-component symlinks
- [CONVENTION] Memory: cp-based seeding → symlink-based
- ...

### Reference Impact
- N files contain references to changed paths
- N code repos need updates
- N projects affected
```

#### 3b. Batch Questions

Present ALL findings as a single grouped summary, then ask ONE confirmation with the option to drill into specifics. Do NOT ask one AskUserQuestion per ambiguity — batch them.

```
## Findings & Decisions Needed

### Unambiguous Changes (will include in plan)
- _projects.conf: 3 → 4 columns (added COLLAB field)
- _setup.sh: memory symlinks instead of copies
- ...

### Ambiguous Changes (need your input)
1. `_Notes/` removed from BrainShared — distribute to _ActiveSessions/, _DevLog/, _Workbench/? Or delete?
2. `_Workbench/` new in BrainShared — create locally? Move anything there?
3. ...

Enter numbers to discuss, or "ok" to proceed with defaults: [ ]
```

If the user enters numbers, discuss those specific items via AskUserQuestion — one item at a time. After each response, check whether unresolved items remain and continue until all are resolved.

If the user enters "ok":
- **If the Ambiguous Changes list is non-empty:** Do NOT proceed. Use AskUserQuestion to ask about the first unresolved item (e.g., "You entered 'ok' but I need your intent on this: `_Notes/` disappeared — was it moved, renamed, or deleted?"). Continue item-by-item until all are resolved. Only then proceed to Step 3c.
- **If the Ambiguous Changes list is empty:** Proceed immediately to Step 3c.

Generating a plan that uses "reasonable defaults" for ambiguous changes is a contract violation (invariant 3).

#### 3c. Confirm Understanding

After Q&A, present a summary of what the migration plan will cover:

```
## Migration Plan Scope (Confirm)

1. File moves: N files across M projects
2. Directory creation: N new directories
3. Config migration: _projects.conf format, _setup.sh rewrite
4. Symlink rewiring: N symlinks across M repos
5. Reference updates: N files with path references to update
6. Legacy cleanup: N stale directories/files to remove
7. Validation: brain-check + folder-audit

Proceed to generate plan? [Yes / Adjust scope / Abort]
```

---

### Phase 4: Plan Generation

Generate a superpowers-compatible migration plan and save it.

#### 4a. Structure the Plan

Organize into dependency-ordered phases:

| Phase | Contents | Why this order |
|-------|----------|---------------|
| Phase 0 | Emergency fixes (broken symlinks blocking work) | Unblock immediately |
| Phase A | Text reference updates (docs, global config) | Source-of-truth updated first |
| Phase B | Physical file migration (moves, new directories) | Structure in place before config |
| Phase C | Config migration (_projects.conf, _setup.sh, _sync.conf) | Config matches new structure |
| Phase D | Per-repo updates (project_files/, .gitignore, CLAUDE.md) | Repos updated to match vault |
| Phase E | Symlink rewiring (memory, CLAUDE.md chains) | Links point to new locations |
| Phase F | Legacy cleanup (stale dirs, old files, broken links) | Clean up after migration |
| Phase G | Validation (brain-check, folder-audit) | Verify everything |

#### 4b. Write Plan File

Use the **Write** tool to save to `$BRAIN/_Docs/brain/Plans/YYYY-MM-DD-<description>.md` using superpowers format:

```markdown
# <Description> Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** <one sentence>
**Architecture:** <2-3 sentences>
**Tech Stack:** Brain vault migration

**Date:** YYYY-MM-DD
**Status:** Ready for execution
**Trigger:** <what caused this migration>

---

## What Changed
<summary of differences from Phase 1>

## Current Local State
<snapshot of relevant local state before migration>

## Target State
<what the vault should look like after migration>

---

## Phase 0: Emergency Fixes
- [ ] Step 1: <specific action with exact paths>
  **Verify:** <how to confirm this step worked>
...

## Phase A: Reference Updates
...
(continue for all phases)
```

Each step must include:
- Current state (what exists now — exact paths, content, or configuration)
- Target state (what it should look like after this step)
- Exact file paths
- Exact content changes (old → new) where applicable
- Verification criteria
- Checkbox for tracking

**Rollback:** superpowers:executing-plans runs review checkpoints between phases. If a phase fails, the executor pauses for review before proceeding. No explicit rollback steps needed — the checkpoint model prevents cascading failures.

#### 4c. Per-Project Enumeration

For phases that iterate across projects, list every affected project explicitly:

```markdown
## Phase B: Physical File Migration

### Project: <project-slug>
- [ ] Move `_ActiveSessions/<project-slug>-as.md` → `_ActiveSessions/<project-slug>/session.md`
- [ ] Move `_Notes/Projects/<ProjectName>/_Status.md` → `_ActiveSessions/<project-slug>/_Status.md`
  **Verify:** `ls -la _ActiveSessions/<project-slug>/`

### Project: <another-slug>
- [ ] Create `_ActiveSessions/<another-slug>/session.md` (no existing session file)
...
```

Never use "repeat for all projects" — enumerate each one with its specific paths and state.

---

### Phase 5: Handoff

#### 5a. Present Plan Summary

```
## Migration Plan Generated

Saved: _Docs/brain/Plans/YYYY-MM-DD-<description>.md

Phases: N (0 through G)
Total steps: M
Projects affected: P
Estimated scope: <brief characterization>

## Next Steps

1. Review the plan: Read _Docs/brain/Plans/YYYY-MM-DD-<description>.md
2. Execute: Run superpowers:executing-plans on the plan file
3. After execution: Run /brain-check to validate
```

#### 5b. Offer Immediate Execution

```
Execute this plan now? [Yes — launch superpowers:executing-plans / No — review first]
```

If yes: use the **Skill** tool to invoke `superpowers:executing-plans` with the plan file path.
If no: end with the plan file path for later execution.

---

## Output

- **Migration plan file** — `_Docs/brain/Plans/YYYY-MM-DD-<description>.md` in superpowers-compatible format
- **Terminal summary** — diff categories, impact scope, plan location
- No direct file modifications — all changes happen during plan execution

## Rules

1. **Analysis only — no direct modifications.** This skill generates plans. It never moves files, edits configs, or rewrites scripts directly. All modifications happen during plan execution via superpowers.
2. **Read `_HowThisWorks.md` at runtime.** Never hardcode expected directory structure.
3. **Enumerate every project explicitly.** Migration plans must list each affected project with its specific paths. No "repeat for all projects."
4. **Ask before assuming.** When a change is ambiguous (moved vs deleted, renamed vs replaced), ask the user. Never guess.
5. **Dependency-ordered phases.** Plans must order phases so source-of-truth docs update before consumers, structure exists before references point to it, configs match before scripts run.
6. **Preserve existing gotchas.** Regex caution, _ActiveSessions catastrophic rename warning, code repo scanning, path variant matching — all still apply during analysis and must be flagged in generated plans.
7. **Pre-push mode validates, post-pull mode migrates.** Pre-push checks local consistency against what BrainShared expects. Post-pull plans how to adapt local vault to partner's changes.
8. **Superpowers-compatible output.** Plans use checkbox syntax, include file paths, verification criteria, and the required superpowers header.
9. **If zero differences, say so.** Report vault is consistent and exit. Never manufacture migration work.
10. **Compose with existing skills.** Include `/brain-check` and `/folder-audit` as validation steps in generated plans. Don't duplicate their checks.
