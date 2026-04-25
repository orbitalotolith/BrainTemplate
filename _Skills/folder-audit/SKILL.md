---
name: folder-audit
description: Use when the ~/Development/ folder structure may have drifted — missing Brain directories, broken symlinks, absent memory folders, stale registry entries, or naming convention violations. Also use after creating new projects or setting up a new machine.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Glob, Grep, Read, Write, Edit, AskUserQuestion
---

# Folder Audit

Single-pass structural audit of the entire `~/Development/` tree. Discovers all projects, cross-references their presence in every required location, validates naming conventions and symlink integrity, and interactively repairs issues. Uses Edit to fix files in place and Write to create missing files.

Content quality audits (`/profile-audit`, `/memory-audit`, `/kb-audit`, `/devlog-audit`, `/status-audit`, `/vault-consistency-audit`) check what's *inside* vault files — staleness, misplacement, gaps. `/folder-audit` audits structural correctness — directories exist, symlinks resolve, `_projects.conf` is complete. `/structure-audit` checks code repo internal layout (Universal Project Structure). Run `/folder-audit` after creating new projects, after cloning repos on a new machine, or whenever things feel disorganized.

## Overview

[TBD]

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### Preamble

#### 0a. Verify Run Context

First detect Brain root. Use the **Bash** tool to run:

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
```

If CWD is not under `$BRAIN`, warn the user and ask whether to proceed.

#### 0b. Read Structural Reference

Read `$BRAIN/_HowThisWorks.md` for the authoritative folder layout, naming conventions, symlink architecture, and `_projects.conf` requirements. This is the source of truth — do not hardcode structural rules that are documented there.

#### 0c. Initialize Findings

Create an empty findings list. Each finding has:
- **ID:** `<CATEGORY>-<NUMBER>` (e.g., `STR-001`, `SYM-003`)
- **Severity:** `error`, `warn`, or `info`
- **Project:** Which project this applies to (or `cross-project`)
- **Description:** What's wrong
- **Repair action:** What to do about it

---

### Phase 1: Discovery

Use Glob to build a unified project registry by scanning all sources. A "project" is anything found in any of these locations.

#### 1a. Code Repos

Walk all top-level directories under `$DEV` (excluding the Brain vault itself) for directories containing `.git/`.

```bash
# Scan every top-level category under $DEV, skipping Brain
for dir in "$DEV"/*/; do
  [ "$dir" = "$BRAIN/" ] && continue
  find "$dir" -maxdepth 3 -name .git -type d 2>/dev/null | sed 's|/\.git$||'
done
```

For each repo found, extract:
- `category`: path relative to `$DEV` up to (but not including) the project directory (e.g., `Clients/Acme`, `Personal`, `Freelance`)
- `project_name`: directory name (e.g., `MyProject`, `LibName`)
- `slug`: lowercase project name, no hyphens (e.g., `myproject`, `libname`)
- `full_path`: absolute path to the code repo

#### 1b. Workbench Directories

Walk all symlinks under `$BRAIN/_Workbench/` for project-level directories (flat `<slug>` symlinks).

```bash
# Scan _Workbench/ for project symlinks
ls -la "$BRAIN/_Workbench/" 2>/dev/null
```

Each entry in `_Workbench/` is a `<slug>` symlink pointing to the project's workbench directory. Verify each symlink resolves.

#### 1c. Memory Directories

```bash
ls -d "$BRAIN/_Memory/"*/
```

Each subdirectory is a memory slug. Map each to its expected project.

#### 1d. Project Registry

Read `$BRAIN/_projects.conf` — the single source of truth for all project mappings. Use the **Grep** tool to search:

```bash
grep -v '^#' "$BRAIN/_projects.conf" | grep -v '^$'
```

This gives `SLUG|CATEGORY|CODE_PATH` triples. All project mappings (memory sync, symlinks, health checks) are derived from this file. There is no separate MEMORY_MAP or LINK_TARGETS to parse — `_projects.conf` is the only source.

#### 1f. KnowledgeBase

```bash
ls "$BRAIN/_KnowledgeBase/"*.md
```

Read each file's frontmatter for `tags:` field.

#### 1g. Templates

```bash
ls "$BRAIN/_Templates/"
```

#### 1h. Active Session Files

```bash
ls -d "$BRAIN/_ActiveSessions/"*/ 2>/dev/null | grep -v '_Parked'
ls -d "$BRAIN/_ActiveSessions/_Parked/"*/ 2>/dev/null
```

Map each `<slug>/session.md` directory to its project. Add `has_as_file` boolean to the registry. Track whether it's in `_ActiveSessions/` (active) or `_ActiveSessions/_Parked/` (parked).

#### 1i. Build Registry

Merge all sources into a single project registry. For each unique project:

| Field | Source |
|-------|--------|
| `name` | Directory name from any source |
| `slug` | Lowercase, from memory dir or derived |
| `category` | Path relative to `$DEV` (e.g., `Clients/Acme`, `Personal`, `Freelance`) |
| `has_code_repo` | Found in 1a |
| `has_workbench` | Found in 1b |
| `has_memory_dir` | Found in 1c |
| `in_registry` | Found in 1d |
| `has_as_file` | Found in 1h |
| `as_location` | `active` or `parked` (from 1h) |
| `code_repo_path` | Absolute path |
| `workbench_path` | Absolute path |
| `memory_dir_path` | Absolute path |

The `brain` slug is special — it has a memory directory but no code repo or workbench. Skip code/workbench checks for it.

---

### Phase 2: Validation

Run all checks. Collect findings without making changes.

#### STR — Structure Checks

For each project in the registry:

| ID | Severity | Condition | Description |
|----|----------|-----------|-------------|
| STR-001 | error | `has_code_repo` but NOT `has_workbench` | Code repo `<path>` exists but no matching `_Workbench/<slug>` symlink |
| STR-002 | error | `has_workbench` but NOT `has_code_repo` | `_Workbench/<slug>` exists but no matching code repo (orphaned workbench) |
| STR-003 | error | Project has no `_ActiveSessions/<slug>/_Status.md` | Project missing `_Status.md` |
| STR-004 | error | `has_code_repo` but no `CLAUDE.md` in repo root | Code repo missing `CLAUDE.md` |
| STR-005 | warn | `has_code_repo` but missing `project_files/brain/DevLog/` or `project_files/brain/Workbench/` | Project missing recommended shared subdirs |
| STR-006 | error | Project path hierarchy doesn't match expected pattern | Code repo subcategory and registry category disagree |
| STR-007 | warn | Directory or file name violates naming conventions from `_HowThisWorks.md` (read in step 0b) | Naming violation per vault naming rules |
| STR-008 | error | `_Docs/<slug>/Plans/` directory missing for registered project | Plan directory missing in Brain vault — create it |
| STR-009 | warn | `has_code_repo` but no `project_files/data/` directory | Code repo missing `project_files/data/` directory for runtime data |

**STR-002 nuance:** A workbench symlink without a code repo is only an error if the project is expected to have one. Some projects may be planning-phase only (workbench exists before code). If `_Status.md` exists and has `status: planning` or `status: archived` in frontmatter, downgrade to `info`.

**STR-005 specifics:** The minimum recommended subdirs are `project_files/brain/DevLog/` and `project_files/brain/Workbench/`. Other subdirs are optional — only flag if the project has been active for >30 days (check `_Status.md` `created:` date).

**Naming convention rules** (from `_HowThisWorks.md`):
- `_prefix` for system/meta files: `_Status.md`, `_Brand.md`, `_Workbench/`, `_ActiveSessions/`
- `PascalCase` for project and multi-word folder names: `ProjectA`, `MultiWordProject`
- `lowercase` for system/gitignored directories: `project_files/`, `notes/`
- No spaces in any folder or file names

#### SYM — Symlink Checks

For each project with `has_code_repo`:

| ID | Severity | Condition | Description |
|----|----------|-----------|-------------|
| SYM-001 | error | `project_files/brain/` doesn't exist at all (not a dir, not a symlink) | Shared project directory missing — code repo has no `project_files/brain/` |
| SYM-002 | -- | REMOVED — replaced by SHR-001 | (Old format detection moved to SHR checks) |
| SYM-003 | error | Dangling symlink inside `project_files/brain/` — target does not exist | Brain component symlink broken (session.md, _Status.md, DevLog, Workbench, _Docs, memory, or CLAUDE.md) |
| SYM-004 | error | Root `CLAUDE.md` symlink chain does not resolve — Claude Code cannot find project instructions | Broken CLAUDE.md chain: `<repo>/CLAUDE.md` → `project_files/brain/CLAUDE.md` → Brain. Downgrade to `info` if `has_code_repo` is false (repo not cloned on this machine). |
| SYM-005 | warn | `project_files/` directory doesn't exist at all | `project_files/` directory missing entirely |

**SYM-001 check:**
```bash
# For each code repo:
path="<repo_path>/project_files/brain"
if [ -L "$path" ]; then
  # It's a symlink — old format. SHR-001 handles this, not SYM-001.
elif [ -d "$path" ]; then
  # It's a real directory — correct (new format). No SYM-001 finding.
else
  # Missing entirely — SYM-001 error
fi
```

**SYM-003 check:** For each code repo where `project_files/brain/` is a real directory, check each expected symlink resolves:
```bash
for link in session.md _Status.md DevLog Workbench _Docs memory CLAUDE.md; do
  target="<repo_path>/project_files/brain/$link"
  if [ -L "$target" ] && [ ! -e "$target" ]; then
    # Dangling symlink — SYM-003 error. Report which component and where it pointed.
  fi
done
```

**SYM-004 check:** For each registered project, verify the CLAUDE.md chain resolves:
```bash
repo="<repo_path>"
if [ ! -e "$repo" ]; then
  # Repo not cloned on this machine — downgrade SYM-004 to info
elif [ -L "$repo/CLAUDE.md" ]; then
  resolved=$(readlink -f "$repo/CLAUDE.md" 2>/dev/null)
  if [ -z "$resolved" ] || [ ! -f "$resolved" ]; then
    # Chain broken — SYM-004 error
  fi
else
  # CLAUDE.md is not a symlink (may be a real file) — no SYM-004 finding
fi
```

**STR-008 repair:** `mkdir -p "$BRAIN/_Docs/<slug>/Plans"`

**STR-009 repair:** `mkdir -p "<repo_path>/project_files/data"`

#### MEM — Memory Checks

For each project in the registry (except `brain` which is always present):

| ID | Severity | Condition | Description |
|----|----------|-----------|-------------|
| MEM-001 | error | NOT `has_memory_dir` | No `_Memory/<slug>/` directory for this project |
| MEM-002 | error | `has_memory_dir` but no `MEMORY.md` file inside | Memory directory exists but missing `MEMORY.md` index |
| MEM-003 | error | Project not in `_projects.conf` | Project missing from registry — add a line to `_projects.conf` |
| MEM-004 | warn | `_projects.conf` entry exists but no matching project in `_ActiveSessions/` or `_Memory/` | Stale registry entry — project may have been removed |
| MEM-005 | warn | `.md` files in `_Memory/<slug>/` not listed in that slug's `MEMORY.md` | Unindexed memory files — MEMORY.md index is incomplete |
| MEM-006 | error | `_projects.conf` entries don't match `_Memory/` directories | `_projects.conf` out of sync with `_Memory/` directories |

**MEM-003 check:** `_projects.conf` is the single source of truth. All consumers (`_setup.sh`, `_health-check.sh`, `save-session`, `start-session`) read from it. If a project is missing from `_projects.conf`, it's missing from everything.

**MEM-005 check:** For each `_Memory/<slug>/` directory that contains a `MEMORY.md`:
1. List all `.md` files in the directory, excluding `MEMORY.md` itself
2. Parse `MEMORY.md` for existing markdown link targets — extract filenames from patterns like `[...](filename.md)`
3. Any `.md` file present on disk but not referenced in a link target is unindexed
4. Skip directories that fail MEM-002 (no `MEMORY.md` at all) — that's a separate finding

#### KB — KnowledgeBase Checks

For each file in `_KnowledgeBase/`:

| ID | Severity | Condition | Description |
|----|----------|-----------|-------------|
| KB-001 | warn | File missing `tags: [reference, <domain>]` frontmatter | KB file missing required frontmatter tags |
| KB-002 | warn | File content references a specific project by name (not a general tech topic) | KB file may contain project-specific content — should be cross-project only |

**KB-002 heuristic:** Search for project names from the registry within KB file content. If a file mentions a specific project more than twice, flag it. Single mentions in context (e.g., "discovered while working on ProjectX") are acceptable.

#### AS — Active Session Checks

For each project in the registry:

| ID | Severity | Condition | Description |
|----|----------|-----------|-------------|
| AS-001 | error | Project in `_projects.conf` but no `_ActiveSessions/<slug>/session.md` (active or parked) | Missing active session file for registered project |
| AS-002 | warn | `<slug>/session.md` exists but slug not in `_projects.conf` | Orphan active session directory |
| AS-003 | error | AS dir in `_Parked/` but `_Status.md` has `status: active`; or AS dir active but `_Status.md` has `status: archived` | Active session location contradicts project status |
| AS-004 | error | Directory in `_ActiveSessions/` doesn't match `<slug>/` naming pattern or missing `session.md` | AS directory structure violation — must be `<slug>/session.md` |
| AS-005 | warn | AS file missing required frontmatter fields (`tags`, `project`, `status`, `updated`, `last-saved-by`) | AS file has incomplete frontmatter |
| AS-006 | error | `_ActiveSessions/_Parked/` directory doesn't exist | Missing `_Parked/` subdirectory |

**AS-001 repair:** Create `_ActiveSessions/<slug>/session.md` from template (mkdir -p the directory first):
```markdown
---
tags: [active-session]
project: <ProjectName>
status: active
updated: <YYYY-MM-DD>
last-saved-by: <$(hostname -s)>
---

# <ProjectName>

**Current:** No handoff recorded yet.

## Handoff
- **Left off:** No handoff recorded
- **What got done:** --
- **Next:** Check `_Status.md` for current state
- **Context:** --
- **Code state:** Unknown
```

**AS-002 repair:** Ask user — delete the orphan file, or register the project?

**AS-003 repair:** Ask user — move the file to match the status, or update the status?

**AS-004 repair:** Rename the directory to match `<slug>/` pattern and ensure `session.md` exists inside. Derive slug from `_projects.conf` if possible, otherwise ask user.

**AS-005 repair:** Add missing frontmatter fields using defaults (`updated: <today>`, `last-saved-by: <hostname>`, etc.).

**AS-006 repair:** `mkdir -p "$BRAIN/_ActiveSessions/_Parked/"`

#### SHR — Brain-Canonical Structure Checks

Brain holds all real files. Code repos contain symlinks pointing into Brain. For each project in the registry (except `brain`):

| ID | Severity | Condition | Description |
|----|----------|-----------|-------------|
| SHR-001 | error | Brain `_ClaudeSettings/<slug>/CLAUDE.md` missing or is a symlink | CLAUDE.md should be a real file in Brain |
| SHR-002 | error | Brain `_ActiveSessions/<slug>/_Status.md` missing or is a symlink | _Status.md should be a real file in Brain |
| SHR-003 | error | Brain `_DevLog/<slug>/` missing or is a symlink | DevLog should be a real directory in Brain |
| SHR-004 | error | Brain `_Workbench/<slug>/` missing or is a symlink | Workbench should be a real directory in Brain |
| SHR-005 | error | Brain `_Memory/<slug>/` missing or is a symlink | Memory should be a real directory in Brain |
| SHR-006 | error | Claude memory `~/.claude/projects/<path>/memory/` not symlinked to Brain | Claude memory should symlink to `$BRAIN/_Memory/<slug>/` |
| SHR-007 | error | Brain `_ActiveSessions/<slug>/session.md` missing or is a symlink | session.md should be a real file in Brain |
| SHR-008 | error | Code repo `project_files/brain/` items are real files (not symlinks to Brain) | Code repo should contain symlinks, not real files — run _setup.sh to migrate |
| SHR-009 | warn | Solo repo `.gitignore` doesn't ignore `project_files/brain/` | Solo repo .gitignore needs `project_files/brain/` rule |
| SHR-010 | warn | `project_files/brain/_Docs` symlink missing | _Docs symlink not created (run _setup.sh) |
| SHR-011 | warn | Code repo has `project_files/brain/` directory but `.gitignore` has no `project_files/brain/` rule | `.gitignore` should exclude `project_files/brain/` to prevent committing symlinks |

**SHR-008 check:** For each item in `project_files/brain/` (CLAUDE.md, memory, session.md, _Status.md, DevLog, Workbench), verify it's a symlink pointing to the correct Brain path. If it's a real file/dir, flag as SHR-008.

**SHR-011 check:** For each code repo with a `project_files/brain/` directory, check that `.gitignore` contains a rule matching `project_files/brain/`. If no rule exists, flag as SHR-011. This prevents accidentally committing symlinks to version control.

#### CLN — Cleanup Checks

Detect stale artifacts from migrations or project removals.

| ID | Severity | Condition | Description |
|----|----------|-----------|-------------|
| CLN-001 | warn | `~/.claude/projects/` contains a memory directory that doesn't correspond to any current `_projects.conf` entry | Stale Claude memory directory — project may have been removed or renamed |
| CLN-002 | error | Project slug in `_projects.conf` has no `_ActiveSessions/<slug>/_Status.md` file (active or parked) | Missing `_Status.md` for registered project |

**CLN-001 check:**
```bash
# List all memory dirs under ~/.claude/projects/
for memdir in "$HOME/.claude/projects"/*/memory; do
  [ -d "$memdir" ] || continue
  # Extract the project path from the parent directory name
  parent=$(basename "$(dirname "$memdir")")
  # Check if this maps to a current _projects.conf entry by checking symlink target
  if [ -L "$memdir" ]; then
    target=$(readlink "$memdir")
    slug=$(basename "$target")
    # Verify slug exists in _projects.conf
    if ! grep -q "^${slug}|" "$BRAIN/_projects.conf" 2>/dev/null; then
      # Stale — flag it
    fi
  fi
done
```

**CLN-002 check:** For each slug in `_projects.conf`, verify `_ActiveSessions/<slug>/_Status.md` or `_ActiveSessions/_Parked/<slug>/_Status.md` exists as a real file. This is separate from the AS-001 session.md check — `_Status.md` is the living project knowledge file.

**CLN-001 repair:** List the stale directories for the user. Ask whether to remove each one (`rm -rf` the symlink or directory).

**CLN-002 repair:** Create `_Status.md` from template (same as STR-003 template in Group 2).

#### TPL — Template Checks

For each file/directory in `_Templates/`:

| ID | Severity | Condition | Description |
|----|----------|-----------|-------------|
| TPL-001 | warn | `.md` file contains malformed Templater syntax (`<% ... %>` with unclosed tags) | Template has invalid Templater syntax |
| TPL-002 | info | Template directory/file not referenced in any `_Status.md` or skill | Template may be unused |

---

### Phase 3: Report

After all checks complete, present findings grouped by project:

```
## Folder Audit Report

### ProjectAlpha (CategoryA/SubCategory/ProjectAlpha)
- [error] STR-001: No matching _Workbench/<slug> symlink
- [error] SYM-001: project_files/brain/ directory missing
- [error] MEM-001: No _Memory/projectalpha/ directory
- [warn] STR-005: Missing recommended subdirs: Architecture/, Runbooks/

### Cross-Project
- [warn] MEM-005: 3 unindexed memory files in _Memory/brain/
- [error] MEM-006: _projects.conf out of sync with _Memory/ directories
- [warn] KB-001: BLE.md missing frontmatter tags

### Summary
Errors: 5 | Warnings: 2 | Info: 0 | Passed: 18
```

If zero findings across all checks, report that the structure is clean and stop. Do not manufacture findings.

---

### Phase 4: Interactive Repair

Use **AskUserQuestion** to ask about repair options:

- **Fix all** — apply all repairs, errors first, then warnings
- **Fix errors only** — skip warnings and info
- **Fix by project** — choose which projects to repair
- **Report only** — stop here, no changes

#### Repair Groups

Execute repairs in this order:

##### Group 1: Create Missing Directories

For STR-001 (missing workbench symlinks), MEM-001 (missing memory dirs), STR-005 (missing subdirs):

```bash
# Memory directory
mkdir -p "$BRAIN/_Memory/<slug>"
```

##### Group 2: Create Missing Files

For STR-003 (missing `_Status.md`), MEM-002 (missing `MEMORY.md`):

**`_Status.md` template** (matches `create-project` scaffold):
```markdown
---
tags: [project, active]
created: <YYYY-MM-DD>
status: active
---
# <ProjectName>

## Overview
[TBD — describe this project]

## Current Focus
Initial setup.

## Active Decisions
- None yet

## Gotchas
- None yet
```

**`MEMORY.md` template:**
```markdown
# Memory Index
```

For MEM-005 (unindexed memory files) — auto-index by reading each file's frontmatter:

1. Read the unindexed file's YAML frontmatter `name` and `description` fields
2. Append to `MEMORY.md`: `- [<name>](<filename>.md) — <description>`
3. If a file has no frontmatter or is missing `name`/`description`, flag it for manual review instead of auto-indexing — present via `AskUserQuestion` with the file path and first few lines

For STR-004 (missing `CLAUDE.md` in code repo) — only create if the code repo exists and is a git repo:
```markdown
# <ProjectName>

## Project Overview
[TBD]

## Project Structure
[TBD]

## Architecture
[TBD]

## Development Commands
[TBD]

## Key Dependencies
[TBD]

## Naming Conventions
[TBD]
```

##### Group 3: Fix Symlinks

For SYM-001 (missing `project_files/brain/` directory) — create the real directory structure. If the project has SHR findings too, defer to Group 6 instead:

```bash
mkdir -p "<repo_path>/project_files/brain/{DevLog,Workbench,memory}"
```

Note: SYM-002 is removed (old format detection moved to SHR-001). Old-format symlinks are converted via Group 6.

##### Group 4: Update Project Registry

For MEM-003 (missing from registry) and MEM-004 (stale entry):

Add one line to `$BRAIN/_projects.conf`:
```
<slug>|<Category>|<Category>/<ProjectName>
```

All consumers (`_setup.sh`, `_health-check.sh`, `save-session`, `start-session`) read from `_projects.conf` automatically — no other files need updating.

For stale entries (MEM-004), remove the line from `$BRAIN/_projects.conf`.

##### Group 5: Move Misplaced Items

For STR-006 (wrong hierarchy). Code repo internal layout moves (UPS checks) are handled by `/structure-audit`.

For each misplaced item:

These require individual judgment. For each item:
1. Explain where it currently is and where it should be
2. Show the proposed move command
3. Ask for confirmation before executing
4. After moving, update any symlinks, `_projects.conf` entries, or symlink references that reference the old path

Never batch-move without per-item confirmation.

##### Group 6: Convert to Brain-Canonical Format (SHR)

For SHR findings, the repair migrates real files from code repo to Brain and creates reversed symlinks. Execute in this order for each project:

**Step A: Ensure Brain directories exist**
```bash
mkdir -p "$BRAIN/_ClaudeSettings/$slug"
mkdir -p "$BRAIN/_Memory/$slug"
mkdir -p "$BRAIN/_ActiveSessions/$slug"
mkdir -p "$BRAIN/_DevLog/$slug"
mkdir -p "$BRAIN/_Workbench/$slug"
```

**Step B: Move real files from code repo to Brain**
For each item in `project_files/brain/` that is a real file (not a symlink):
1. Move `CLAUDE.md` → `$BRAIN/_ClaudeSettings/$slug/CLAUDE.md`
2. Move `memory/*` → `$BRAIN/_Memory/$slug/`
3. Move `session.md` → `$BRAIN/_ActiveSessions/$slug/session.md`
4. Move `_Status.md` → `$BRAIN/_ActiveSessions/$slug/_Status.md`
5. Move `DevLog/*` → `$BRAIN/_DevLog/$slug/`
6. Move `Workbench/*` → `$BRAIN/_Workbench/$slug/`

Skip files that already exist in Brain (Brain wins on conflict).

**Step C: Create code repo symlinks (→ Brain)**

For each symlink below, use the Bash tool to check whether it already resolves before creating it:

```bash
mkdir -p "$repo/project_files/brain"

safe_symlink() {
  local target="$1"
  local link="$2"
  if [ -e "$link" ]; then
    echo "EXISTS: $link → $(readlink "$link")"
    echo "SKIP: existing symlink resolves — per-item confirmation required before replacing"
    return 1
  fi
  ln -sfn "$target" "$link"
}

safe_symlink "$BRAIN/_ClaudeSettings/$slug/CLAUDE.md" "$repo/project_files/brain/CLAUDE.md"
safe_symlink "$BRAIN/_Memory/$slug"                   "$repo/project_files/brain/memory"
safe_symlink "$BRAIN/_ActiveSessions/$slug/session.md" "$repo/project_files/brain/session.md"
safe_symlink "$BRAIN/_ActiveSessions/$slug/_Status.md" "$repo/project_files/brain/_Status.md"
safe_symlink "$BRAIN/_DevLog/$slug"                   "$repo/project_files/brain/DevLog"
safe_symlink "$BRAIN/_Workbench/$slug"                "$repo/project_files/brain/Workbench"
safe_symlink "$BRAIN/_Docs/$slug"                     "$repo/project_files/brain/_Docs"
```

For any symlink that returns 1 (already resolves), use AskUserQuestion to confirm per-item before calling `ln -sfn` directly to replace it.

**Step D: Create Claude memory symlink (one hop to Brain)**
```bash
prefix=$(echo "$HOME" | tr '/' '-' | sed 's/^-//')
suffix="Development-$(echo "$code" | tr '/' '-')"
claude_memory="$HOME/.claude/projects/-${prefix}-$suffix/memory"
rm -rf "$claude_memory"
mkdir -p "$(dirname "$claude_memory")"
ln -sfn "$BRAIN/_Memory/$slug" "$claude_memory"
```

**Step E: Update code repo .gitignore**
For solo repos:
```gitignore
project_files/brain/
```

For collab repos:
```gitignore
project_files/*
!project_files/brain/
project_files/brain/DevLog
project_files/brain/Workbench
project_files/brain/_Docs
project_files/brain/.DS_Store
```

**Step F: Verify** — Check all Brain files are real (not symlinks), all code repo items are symlinks pointing to correct Brain paths.

#### After Repairs

After all approved repairs are complete:

1. Show summary of changes made
2. Run `bash "$BRAIN/_health-check.sh"` automatically to verify
3. If health check passes, report success
4. If health check fails, show remaining issues

Do NOT auto-commit or auto-push. The user handles git (or Obsidian auto-syncs).

---

## Output

After Phase 3 (or Phase 4 if repairs were applied), save the full report to:

```
$BRAIN_ROOT/_Docs/brain/Reports/folder-audit-YYYY-MM-DD.md
```

Use today's date. The report file should include:
- Frontmatter: `tags: [report, folder-audit]`, `date: YYYY-MM-DD`
- The full Phase 3 report (all findings grouped by project, with severity and IDs)
- If repairs were applied, append a "Repairs Applied" section listing what changed
- If report-only, note that no changes were made

If a report already exists for today's date, overwrite it (re-runs replace previous results).

## Rules

- This skill is **read-only until the user approves repairs** in Phase 4
- Never auto-commit or auto-push
- Dynamic discovery — scan the filesystem, don't hardcode project names
- Read `_HowThisWorks.md` at runtime — it's the source of truth for structural rules
- The `brain` slug is special: it has a memory directory but no code repo or notes directory. Skip code/notes/symlink checks for it.
- `_health-check.sh` already validates symlinks and `_projects.conf` mechanically. This skill adds reasoning about completeness, naming, and misplaced items. After repairs, run `_health-check.sh` as verification.
- When creating files, match the templates used by `create-project/SKILL.md`
- If zero findings, say so honestly and stop — don't manufacture work
- STR-002 (orphaned workbench) is expected for archived or planning-phase projects — check `_Status.md` frontmatter before flagging as error
- Repairs in Groups 1-4 can be batch-confirmed. Group 5 (moves) and Group 6 (format conversion) require per-project confirmation.
