---
name: pull-projectshared
description: For project collaboration repos — pull latest changes from the project's shared partner repo
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, AskUserQuestion, Skill
---

# Pull Project Shared

## Overview

For collab repos: pull partner's changes, write their content to Brain's canonical locations, restore symlinks. Handles first-time setup including cloning.

**Usage:**
- `/pull-projectshared` — from inside an existing repo, pull latest
- `/pull-projectshared <git-url>` — clone a new collab repo and set everything up

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory before proceeding.

### 0b. Clone if URL Provided

If an argument is provided and it looks like a git URL (contains `.git` or `github.com` or `gitlab.com`):

Use the **Bash** tool to run:

```bash
BRAIN="${BRAIN_ROOT:-}"
if [ -z "$BRAIN" ]; then
  BRAIN=$(dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null)
fi
DEV="$HOME/Development"
```

1. Clone the repo into `$DEV/` preserving the repo name. Use the **Bash** tool to run:
   ```bash
   repo_name=$(basename "$URL" .git)
   ```
2. Ask the user where under `$DEV/` to clone (suggest `$DEV/$repo_name`). Use **AskUserQuestion** to ask.
3. Clone. Use the **Bash** tool to run:
   ```bash
   git clone "$URL" "$clone_path"
   repo="$clone_path"
   ```
4. Continue to step 1 using the cloned path as `$repo`.

If no argument is provided, use CWD as `$repo`.

### 1. Project Resolution

```bash
BRAIN="${BRAIN_ROOT:-}"
if [ -z "$BRAIN" ]; then
  BRAIN=$(dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null)
fi
DEV="$HOME/Development"
```

1. Read `$BRAIN/_projects.conf`
2. Get repo path, strip `~/Development/` prefix → CODE_PATH
3. Match against CODE_PATH entries (longest prefix wins) → SLUG, CATEGORY, CODE_PATH, COLLAB
4. If no match → check for `project_files/brain/.collab.conf` in the repo:
   - If found: read SLUG, CATEGORY, COLLAB from it. Derive CODE_PATH from repo path minus `~/Development/`.
   - Auto-register: append `SLUG|CATEGORY|CODE_PATH|COLLAB` to `$BRAIN/_projects.conf`
   - Continue with resolved values.
   - If `.collab.conf` not found: "Not a registered project. Run `/create-project` to register it."
5. If slug is `brain`: "Use `/pull-brainshared` for Brain vault changes."
6. If COLLAB is not `collab`: "This is a solo repo — no shared content to pull."

### 1b. First-Time Setup — Create Brain Directories

Ensure all Brain directories exist for this project:

```bash
mkdir -p "$BRAIN/_ClaudeSettings/$SLUG"
mkdir -p "$BRAIN/_ActiveSessions/$SLUG"
mkdir -p "$BRAIN/_Memory/$SLUG"
mkdir -p "$BRAIN/_DevLog/$SLUG"
mkdir -p "$BRAIN/_Workbench/$SLUG"
mkdir -p "$BRAIN/_Docs/$SLUG"
```

Also ensure the Claude Code memory symlink exists:

```bash
repo_abs=$(cd "$repo" && pwd)
claude_proj="$HOME/.claude/projects/-$(echo "$repo_abs" | tr '/' '-')/memory"
if [ ! -L "$claude_proj" ]; then
  mkdir -p "$(dirname "$claude_proj")"
  ln -sfn "$BRAIN/_Memory/$SLUG" "$claude_proj"
fi
```

Create the root `CLAUDE.md` symlink:

```bash
if [ ! -L "$repo/CLAUDE.md" ]; then
  ln -sfn "project_files/brain/CLAUDE.md" "$repo/CLAUDE.md"
fi
```

Create the `_Docs` symlink:

```bash
if [ ! -L "$repo/project_files/brain/_Docs" ]; then
  ln -sfn "$BRAIN/_Docs/$SLUG" "$repo/project_files/brain/_Docs"
fi
```

These are all no-ops if the directories/symlinks already exist.

### 2. Detect Brain Root and Read Sync Config
- Source `_sync.conf`, parse `SHARED_PROJECTS` for this slug
- Extract `LAST_PUSH_COMMIT` for this project

### 3. Check for Unpushed Local Brain Changes

**If LAST_PUSH_COMMIT does not exist** (first pull, never pushed) OR **LAST_PUSH_COMMIT is not in history** (stale baseline):
- If stale: warn "LAST_PUSH_COMMIT not found in history — skipping unpushed-change check"
- Skip this check entirely — no baseline to compare against
- Proceed to step 4

**If LAST_PUSH_COMMIT exists:**
Compare Brain canonical files against last committed versions:
```bash
for each brain file (CLAUDE.md, session.md, _Status.md, memory/, DevLog/, Workbench/):
  diff "$BRAIN/<canonical_path>" <(git show "$LAST_PUSH_COMMIT:project_files/brain/<file>")
```
This avoids the symlink confusion — compares Brain's real files against what was last pushed.

If unpushed changes found:
```
WARNING: You have unpushed local brain changes:
  <file list>
Run /push-projectshared first to save your work.
Continue anyway? [y/N]
```
**Default is NO.** Must explicitly confirm to proceed.

### 4. Git Pull
**assume-unchanged flags remain SET** — git skips working-tree checks for brain files, allowing pull to succeed even though symlinks differ from committed real files.

```bash
ORIG_HEAD=$(git rev-parse HEAD)
git pull --ff-only
NEW_HEAD=$(git rev-parse HEAD)
```
If fails: abort, suggest resolving. Do NOT clear assume-unchanged (they're still set, which is the normal state).

### 5. Clear assume-unchanged flags

```bash
cd "$repo"
for f in project_files/brain/CLAUDE.md project_files/brain/session.md \
         project_files/brain/_Status.md project_files/brain/memory \
         project_files/brain/DevLog project_files/brain/Workbench; do
  git update-index --no-assume-unchanged "$f" 2>/dev/null || true
done
```

### 6. Verification Display

Before writing anything to Brain, show exactly what's about to change.

Compare pulled real files (now in working tree after git pull) against Brain canonical files:
```bash
brain_dir="$repo/project_files/brain"

# For each brain file, diff Brain canonical vs pulled version
diff "$BRAIN/_ClaudeSettings/$SLUG/CLAUDE.md" "$brain_dir/CLAUDE.md"
diff "$BRAIN/_ActiveSessions/$SLUG/session.md" "$brain_dir/session.md"
diff "$BRAIN/_ActiveSessions/$SLUG/_Status.md" "$brain_dir/_Status.md"
# For directories: diff -r for memory/, DevLog/, Workbench/
diff -r "$BRAIN/_Memory/$SLUG/" "$brain_dir/memory/"
diff -r "$BRAIN/_DevLog/$SLUG/" "$brain_dir/DevLog/"
diff -r "$BRAIN/_Workbench/$SLUG/" "$brain_dir/Workbench/"
```

Display per-file summary:
- **Changed:** files that differ between Brain and pulled version
- **New:** files in pulled version that don't exist in Brain
- **Removed:** files in Brain that don't exist in pulled version (for additive dirs — memory, DevLog, Workbench — note these will be KEPT, not deleted)

Show the diffs. Let the user ask questions about any changes. User confirms before proceeding.

If user aborts: restore symlinks (step 8), set assume-unchanged (step 9), stop. Do NOT write to Brain.

### 7. Write Pulled Content to Brain

Copy the pulled real files into Brain's canonical locations:

```bash
brain_dir="$repo/project_files/brain"

# CLAUDE.md — authoritative override
[ -f "$brain_dir/CLAUDE.md" ] && [ ! -L "$brain_dir/CLAUDE.md" ] && \
  cp "$brain_dir/CLAUDE.md" "$BRAIN/_ClaudeSettings/$SLUG/CLAUDE.md"

# session.md — authoritative override
[ -f "$brain_dir/session.md" ] && [ ! -L "$brain_dir/session.md" ] && \
  cp "$brain_dir/session.md" "$BRAIN/_ActiveSessions/$SLUG/session.md"

# _Status.md — authoritative override
[ -f "$brain_dir/_Status.md" ] && [ ! -L "$brain_dir/_Status.md" ] && \
  cp "$brain_dir/_Status.md" "$BRAIN/_ActiveSessions/$SLUG/_Status.md"

# memory/ — additive only (cp -n for files, auto-merge MEMORY.md)
if [ -d "$brain_dir/memory" ] && [ ! -L "$brain_dir/memory" ]; then
  # Auto-merge MEMORY.md (combine lines, deduplicate, sort)
  # cp -n for individual memory files (never overwrite local)
  cp -Rn "$brain_dir/memory/"* "$BRAIN/_Memory/$SLUG/" 2>/dev/null
fi

# DevLog/ — additive only
if [ -d "$brain_dir/DevLog" ] && [ ! -L "$brain_dir/DevLog" ]; then
  mkdir -p "$BRAIN/_DevLog/$SLUG"
  cp -Rn "$brain_dir/DevLog/"* "$BRAIN/_DevLog/$SLUG/" 2>/dev/null
fi

# Workbench/ — additive only
if [ -d "$brain_dir/Workbench" ] && [ ! -L "$brain_dir/Workbench" ]; then
  mkdir -p "$BRAIN/_Workbench/$SLUG"
  cp -Rn "$brain_dir/Workbench/"* "$BRAIN/_Workbench/$SLUG/" 2>/dev/null
fi
```

**MEMORY.md auto-merge:** Combine lines from pulled and local MEMORY.md, deduplicate, sort. Same logic as push.

**CLAUDE.md, session.md, _Status.md** — authoritative override (pulled version wins).

**Memory, DevLog, Workbench** — additive only (`cp -n`, never delete local files).

### 8. Restore Symlinks

Replace the pulled real files with symlinks back to Brain:

```bash
brain_dir="$repo/project_files/brain"

rm -f "$brain_dir/CLAUDE.md" "$brain_dir/session.md" "$brain_dir/_Status.md"
rm -rf "$brain_dir/memory" "$brain_dir/DevLog" "$brain_dir/Workbench"

ln -sfn "$BRAIN/_ClaudeSettings/$SLUG/CLAUDE.md" "$brain_dir/CLAUDE.md"
ln -sfn "$BRAIN/_ActiveSessions/$SLUG/session.md" "$brain_dir/session.md"
ln -sfn "$BRAIN/_ActiveSessions/$SLUG/_Status.md" "$brain_dir/_Status.md"
ln -sfn "$BRAIN/_Memory/$SLUG" "$brain_dir/memory"
ln -sfn "$BRAIN/_DevLog/$SLUG" "$brain_dir/DevLog"
ln -sfn "$BRAIN/_Workbench/$SLUG" "$brain_dir/Workbench"
```

### 9. Set assume-unchanged flags

```bash
cd "$repo"
for f in project_files/brain/CLAUDE.md project_files/brain/session.md \
         project_files/brain/_Status.md project_files/brain/memory \
         project_files/brain/DevLog project_files/brain/Workbench; do
  git update-index --assume-unchanged "$f" 2>/dev/null || true
done
```

### 10. Update Sync State

Update `_sync.conf` SHARED_PROJECTS entry:
```
SLUG|REMOTE_URL|LAST_PUSH_COMMIT|LAST_PUSH_DATE|LAST_PULL_COMMIT|LAST_PULL_DATE
```
Where `LAST_PULL_COMMIT = $(git rev-parse HEAD)`.

Use Write tool to rewrite `_sync.conf`, preserving all other entries.

### 11. Show Partner Status

Read `$BRAIN/_ActiveSessions/$SLUG/session.md` and display partner's section(s):

```bash
source "$BRAIN/_sync.conf" 2>/dev/null
identity="${SYNC_IDENTITY:-$(hostname -s)}"
```

Parse session.md for sections NOT matching your identity. For each partner section, display:
- Partner identity and last update date
- Current status line
- What they're working on
- Their next steps

If no partner sections exist: "No partner sessions recorded yet."

## Output

```
=== Pull Project Shared: <slug> ===
Remote: <remote-url>
Pull: [up to date | N commits pulled]
Brain updated: N files written
Symlinks: restored
Partner: [<identity> last active <date> | no partner sessions]
```

## Rules

- Only for collab repos (COLLAB=collab in _projects.conf)
- Pulled version is authoritative for CLAUDE.md, session.md, _Status.md
- Memory, DevLog, Workbench are additive only — never delete local files
- MEMORY.md auto-merges (combine, deduplicate, sort)
- Always restore symlinks and set assume-unchanged after pull — even if interrupted
- If interrupted: `_setup.sh` detects real files and recreates symlinks
- Shared files: CLAUDE.md, session.md, _Status.md, memory/, DevLog/, Workbench/
- Never pull _Docs — those are Brain-only content
- The `brain` slug is not supported — use `/pull-brainshared` instead
- assume-unchanged flags remain SET during git pull; clear only after pull completes
- Verification display with per-file diffs shown before writing to Brain; user confirms
