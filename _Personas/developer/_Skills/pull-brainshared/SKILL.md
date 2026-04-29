---
name: pull-brainshared
description: For vault-level shared infrastructure — pull latest _Skills/, global settings, and brain memories from BrainShared
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, AskUserQuestion, Skill
---

# Pull Brain

**Run from:** Any directory. Brain root is auto-detected via `$BRAIN_ROOT`. No CWD dependency.

Pull shared infrastructure from BrainShared and per-project shared repos into your private Brain. This is the fast, simple operation — no merge logic, just override with the latest from main.

**Golden rule:** Push before you pull. If you have local changes, `/push-brainshared` first to save them to shared, then `/pull-brainshared` to get your partner's changes. Otherwise your local changes may be overwritten.

**What gets pulled from BrainShared:**
Everything in the BrainShared repo is synced to local. The repo itself defines what's shared — no hardcoded path list. Sync modes:
- **Purely shared directories** (e.g., `_KnowledgeBase/`, `_Skills/`, `_Templates/`) — authoritative override (`rsync --delete`)
- **Mixed directories** (`_ClaudeSettings/`, `_Memory/`) — sync only the subdirectories that exist in BrainShared, never `--delete` the parent. Local-only subdirectories (per-project CLAUDE.md files, per-project memories) are left untouched.
- **Files** — authoritative override (direct copy)

**What gets pulled from per-project repos:**
- `memory/` → `_Memory/<slug>/` — additive only
- `session/<slug>/session.md` → `_ActiveSessions/<slug>/session.md` — authoritative override

**What is NEVER pulled:**
- `_Profile/`, `_Agents/`, `_projects.conf`, `_DevLog/` — private, never in shared repos

## Overview

[TBD]

## Arguments

| Flag | Description |
|------|-------------|
| `--depth=1` | Shallow clone depth used when fetching BrainShared (internal — not user-configurable) |
| `--delete` | rsync flag used for purely shared directories — removes local files not present in shared source |
| `--ff-only` | git pull mode used when syncing Brain git before writing — aborts if fast-forward is not possible |

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### 1. Detect Brain Root and Read Sync Config

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

SYNC_CONF="$BRAIN/_sync.conf"
if [ ! -f "$SYNC_CONF" ]; then
  echo "No _sync.conf found. Copy $BRAIN/_sync.conf.template and configure it."
  exit 1
fi
source "$SYNC_CONF"
```

#### Auto-Migrate Old Config Format

If old format fields exist (`LAST_SYNC_COMMIT`, `PERSONAL_SYNC_BRANCH`), migrate. Use the **Bash** tool to run:

```bash
if [ -n "${LAST_SYNC_COMMIT:-}" ] && [ -z "${LAST_PULL_COMMIT:-}" ]; then
  echo "Migrating _sync.conf from old format..."
  LAST_PULL_COMMIT="$LAST_SYNC_COMMIT"
  LAST_PULL_DATE="${LAST_SYNC_DATE:-}"
  LAST_PUSH_COMMIT=""
  LAST_PUSH_DATE=""
  # Rewrite _sync.conf with new format using Write tool
fi
```

Validate:
```bash
if [ -z "$SHARED_BRAIN_REMOTE" ]; then
  echo "SHARED_BRAIN_REMOTE must be set in _sync.conf"
  exit 1
fi
BRANCH="${SHARED_BRAIN_BRANCH:-main}"
```

### 2. Check for Unpushed Local Changes

Before overwriting, check if the user has local modifications to shared content that haven't been pushed. Use the **Bash** tool to run:

```bash
cd "$BRAIN"

# Private paths — never shared, excluded from unpushed check
PRIVATE_PATTERN="^(_Profile/|_Agents/|_projects\.conf$|_sync\.conf$|_DevLog/|_ActiveSessions/|_Workbench/|_ClaudeSettings/(?!global/|brain/)|_Memory/(?!brain/)|settings\.json$|\.claude/)"

# Portable filter: BSD grep (macOS default) lacks -P. Use awk — POSIX, identical on macOS and Linux.
# Reads path list from stdin, writes non-private paths to stdout.
# Keep in sync with PRIVATE_PATTERN above.
filter_private() {
  awk '
    /^(_Profile|_Agents|_DevLog|_ActiveSessions|_Workbench|\.claude)\// { next }
    /^(_projects\.conf|_sync\.conf|settings\.json)$/ { next }
    /^_ClaudeSettings\// && !/^_ClaudeSettings\/(global|brain)\// { next }
    /^_Memory\// && !/^_Memory\/brain\// { next }
    { print }
  '
}

UNPUSHED=""
if [ -n "${LAST_LOCAL_PUSH_COMMIT:-}" ]; then
  UNPUSHED=$(git diff --name-only "$LAST_LOCAL_PUSH_COMMIT" HEAD 2>/dev/null | filter_private)
fi
```

If unpushed changes found:

> "WARNING: You have unpushed local changes to shared content:
> `<file list>`
>
> These may be overwritten by pulling. Run `/push-brainshared` first to save your work.
> Continue anyway? [y/N]"

**Default is NO.** If user says no, exit cleanly. If user says yes, proceed (their choice to overwrite).

### 3. Clone BrainShared to Temp Dir

Use the **Bash** tool to run:

```bash
PULL_TMP="/tmp/brainshared-pull-$$"
echo "Fetching BrainShared from $SHARED_BRAIN_REMOTE..."

if git clone --depth=1 --branch "$BRANCH" "$SHARED_BRAIN_REMOTE" "$PULL_TMP" 2>&1; then
  echo "  Cloned BrainShared"
  NEW_COMMIT=$(git -C "$PULL_TMP" rev-parse HEAD)
else
  echo "  FAIL: Could not clone $SHARED_BRAIN_REMOTE"
  echo "  Check your SSH keys and remote URL in _sync.conf"
  rm -rf "$PULL_TMP"
  exit 1
fi
```

Check if already up to date:
```bash
if [ -n "${LAST_PULL_COMMIT:-}" ] && [ "$NEW_COMMIT" = "$LAST_PULL_COMMIT" ]; then
  echo "BrainShared is up to date ($NEW_COMMIT)."
  BRAIN_SHARED_UPDATED=false
else
  BRAIN_SHARED_UPDATED=true
fi
```

Don't exit yet — still need to check per-project repos.

### 4. Verification Display

Before writing anything to Brain, show exactly what's about to change.

If BrainShared has updates:

For each top-level entry in the pulled BrainShared content, compare against current Brain state:

```bash
# For each directory in $PULL_TMP (excluding .git):
for entry in $(ls -1 "$PULL_TMP" | grep -v '^\.' ); do
  src="$PULL_TMP/$entry"
  dest="$BRAIN/$entry"
  if [ -d "$src" ]; then
    diff -rq "$dest" "$src" 2>/dev/null | head -20
  else
    diff "$dest" "$src" 2>/dev/null
  fi
done
```

Display per-file summary:
- **Changed:** files that differ between Brain and pulled version
- **New:** files in pulled version that don't exist in Brain
- **Removed:** files in Brain that will be deleted by `rsync --delete` (purely shared dirs only)

Show the diffs for changed files. Let the user ask questions about any changes.

Use AskUserQuestion:
> "Pull these changes into your Brain? [Y/n]"

If user aborts, clean up temp dir and exit cleanly. Do NOT write to Brain.

### 5. Sync BrainShared Content (Repo-Driven)

Instead of syncing a hardcoded list of paths, scan BrainShared's actual contents and sync everything found. This ensures renames, new directories, and structural changes by your partner are always picked up.

#### Mixed directories (shared + local content coexist):
```
_ClaudeSettings/   — only global/ and brain/ come from BrainShared; per-project slugs are local
_Memory/           — only brain/ comes from BrainShared; per-project slugs are local
```

These directories MUST be synced at the subdirectory level — sync only the subdirectories
that exist in BrainShared, never `rsync --delete` the parent directory.

#### Sync algorithm:

```bash
echo ""
echo "=== Syncing from BrainShared ==="

# Mixed directories — sync only subdirectories that exist in BrainShared
MIXED_DIRS=(_ClaudeSettings _Memory)

# Discover all top-level entries in BrainShared (excluding .git)
SHARED_ENTRIES=$(ls -1 "$PULL_TMP" | grep -v '^\.')

for entry in $SHARED_ENTRIES; do
  src="$PULL_TMP/$entry"
  dest="$BRAIN/$entry"

  if [ -d "$src" ]; then
    mkdir -p "$dest"

    # Check if this is a mixed directory
    is_mixed=false
    for md in "${MIXED_DIRS[@]}"; do [ "$entry" = "$md" ] && is_mixed=true; done

    if [ "$is_mixed" = true ]; then
      # Mixed directory — sync each subdirectory individually, skip --delete on parent
      for subdir in $(ls -1 "$src" 2>/dev/null); do
        if [ -d "$src/$subdir" ]; then
          mkdir -p "$dest/$subdir"
          if [ "$entry" = "_Memory" ]; then
            # Memory is always additive — no --delete
            rsync -av "$src/$subdir/" "$dest/$subdir/" 2>&1 | grep '^>' | head -10
            echo "  $entry/$subdir/ synced (additive)"
          else
            # Other mixed dirs — authoritative within the shared subdirectory only
            rsync -av --delete "$src/$subdir/" "$dest/$subdir/" 2>&1 | grep -E '(^>|deleting)' | head -20
            echo "  $entry/$subdir/ synced"
          fi
        else
          # File inside mixed dir — direct copy
          cp "$src/$subdir" "$dest/$subdir"
          echo "  $entry/$subdir synced"
        fi
      done
    else
      # Purely shared directory — authoritative override of entire directory
      rsync -av --delete "$src/" "$dest/" 2>&1 | grep -E '(^>|deleting)' | head -20
      echo "  $entry/ synced"
    fi
  else
    # Single file — authoritative copy
    cp "$src" "$dest"
    echo "  $entry synced"
  fi
done
```


### 6. Propagate to Claude and Validate

Use the **Skill** tool to invoke `/brain-check` to run `_setup.sh` (re-seed memories, fix symlinks) and `_health-check.sh` (validate vault integrity).

Health check failures are **warnings, not blockers** — the pull has already been applied. The user should review and fix.

### 6b. Verify Shared Project Symlinks

After pulling BrainShared and running `_setup.sh`, verify that project symlinks were not damaged by the pull. BrainShared content may overlap with paths that are now symlinks to code repos.

```bash
CONF="$BRAIN/_projects.conf"
SLUGS=(); CATEGORIES=(); CODE_PATHS=(); COLLAB_FLAGS=()
while IFS='|' read -r slug category code collab; do
  [[ "$slug" =~ ^#.*$ || -z "$slug" ]] && continue
  SLUGS+=("$slug"); CATEGORIES+=("$category"); CODE_PATHS+=("$code"); COLLAB_FLAGS+=("${collab:-}")
done < "$CONF"

for i in "${!SLUGS[@]}"; do
  slug="${SLUGS[$i]}"
  code="${CODE_PATHS[$i]}"
  [ "$slug" = "brain" ] && continue
  [ ! -d "$DEV/$code" ] && continue

  repo_memory="$DEV/$code/project_files/brain/memory"

  # Check Brain _Memory — restore symlink if overwritten by pull
  if [ -d "$BRAIN/_Memory/$slug" ] && [ ! -L "$BRAIN/_Memory/$slug" ] && [ -d "$repo_memory" ]; then
    echo "  Restoring _Memory/$slug symlink (overwritten by pull)"
    rm -rf "$BRAIN/_Memory/$slug"
    ln -sfn "$repo_memory" "$BRAIN/_Memory/$slug"
  fi
done
```

This prevents pull-brain from breaking the project symlink structure.

### 7. Update Sync State

Rewrite `_sync.conf` with updated pull tracking. Use the Write tool to rewrite the entire file, preserving all existing values except:
- `LAST_PULL_COMMIT` → `$NEW_COMMIT` (BrainShared commit hash)
- `LAST_PULL_DATE` → today's date
- Per-project `LAST_PULL_COMMIT` values → updated for each project that was pulled

Do NOT commit pulled changes to the local Brain repo. Pulls only copy files and update `_sync.conf` — the user decides when to commit via `/commit`. `LAST_LOCAL_PULL_COMMIT` is no longer tracked (remove the field if present in `_sync.conf`).

### 9. Clean Up

```bash
rm -rf "$PULL_TMP"
rm -rf /tmp/brain-project-pull-*
echo ""
echo "=== Pull complete ==="
echo "BrainShared: $SHARED_BRAIN_REMOTE ($NEW_COMMIT)"
echo "Run /brain-check if you want to re-validate."
```

## Output

[TBD]

## Rules

- Never sync `_Profile/`, `_Agents/`, `_projects.conf`, `_DevLog/` — always private
- `_Memory/brain/` sync is additive — never removes personal globals
- Per-project memory sync is also additive — never removes local project memories
- Always check for unpushed local changes before overwriting — warn and default to abort
- Always run `_setup.sh` after sync to propagate changes to `~/.claude/`
- If clone fails (offline), exit cleanly — never partially apply changes
- The skill is idempotent — running twice with no remote changes is a no-op
