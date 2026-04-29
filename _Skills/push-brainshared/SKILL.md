---
name: push-brainshared
description: For vault-level shared infrastructure — push _Skills/, global settings, and brain memories to BrainShared
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, AskUserQuestion, Skill
---

# Push Brain

**Run from:** Any directory. Brain root is auto-detected via `$BRAIN_ROOT`. No CWD dependency.

Push your local improvements to BrainShared and any registered per-project shared repos. This skill handles the smart work: it fetches the remote, detects what your partner changed, AI-merges conflicts, and pushes the merged result to main.

**Golden rule:** Push before you pull. This preserves your work before overwriting with shared content.

**Pre-push validation:** For best results, run the pre-push checklist before pushing (see `_HowThisWorks.md` → "Pre-Push Checklist"). At minimum: `/brain-check` → `/save-session` → `/push-brainshared`. For thorough validation: also run `/folder-audit` first.

**What gets pushed to BrainShared:**
Everything in the local Brain that is NOT in the private exclusion list. BrainShared's repo structure defines what's shared — no hardcoded path list. The private exclusion list (never pushed) is defined in the "What is NEVER pushed" section below.

**What gets pushed to per-project repos (if registered):**
- `memory/` — from `_Memory/<slug>/`
- `session/<slug>/session.md` — from `_ActiveSessions/<slug>/session.md`

**What is NEVER pushed:**
- `_Profile/` — always private
- `_Agents/` — each partner's personal agent personas are private (not synced)
- `_projects.conf` — always private
- `_sync.conf` — always private
- `_DevLog/` (root-level) — always private
- `_AgentTasks/` — plans, reports, workflow logs are local to each vault
- `_Dashboard.md` — Obsidian dashboard, machine-specific
- `_ClaudeSettings/<slug>/` — per-project CLAUDE.md files are private (only `global/` and `brain/` are shared)
- `_Memory/brain/user_*.md` — identity memories are private (user_role.md, user_profile.md, etc.)

## Overview

[TBD]

## Arguments

| Flag | Description |
|------|-------------|
| `--depth=50` | Shallow clone depth used when fetching BrainShared — enough history for diffs against `LAST_PUSH_COMMIT` |
| `--ff-only` | git pull mode used during race-condition retry — aborts rather than creating a merge commit |
| `--hard` | git reset mode used on push retry to realign with remote HEAD before re-applying local changes |

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
  echo "ERROR: Cannot locate Brain root."
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

If old format fields exist (`LAST_SYNC_COMMIT`, `PERSONAL_SYNC_BRANCH`), migrate them:

```bash
if [ -n "${LAST_SYNC_COMMIT:-}" ] && [ -z "${LAST_PULL_COMMIT:-}" ]; then
  echo "Migrating _sync.conf from old format..."
  LAST_PULL_COMMIT="$LAST_SYNC_COMMIT"
  LAST_PULL_DATE="${LAST_SYNC_DATE:-}"
  LAST_PUSH_COMMIT=""
  LAST_PUSH_DATE=""
  # Rewrite _sync.conf with new format (use Write tool)
fi
```

If `_sync.conf` needed migration, rewrite the entire file with the new format (see Step 10 for the format). Continue with the migrated values.

Validate required fields:
```bash
if [ -z "$SHARED_BRAIN_REMOTE" ]; then
  echo "SHARED_BRAIN_REMOTE must be set in _sync.conf"
  exit 1
fi
```

### 2. Detect Local Changes Since Last Push

Use an exclusion pattern instead of a hardcoded shared-paths list. This detects changes to ANY shared content, even if the partner added new directories or renamed paths.

**Private path exclusion pattern** (never pushed — matches the "What is NEVER pushed" list):
```bash
PRIVATE_PATTERN="^(_Profile/|_Agents/|_projects\.conf$|_sync\.conf$|_DevLog/|_AgentTasks/|_Dashboard\.md$|_ActiveSessions/|_Workbench/|_ClaudeSettings/(?!global/|brain/)|_Memory/(?!brain/)|_Memory/brain/user_|\.claude/|\.git/)"

# Portable filter: BSD grep (macOS default) lacks -P. Use awk — POSIX, identical on macOS and Linux.
# Reads path list from stdin, writes non-private paths to stdout.
# Keep in sync with PRIVATE_PATTERN above.
filter_private() {
  awk '
    /^(_Profile|_Agents|_DevLog|_AgentTasks|_ActiveSessions|_Workbench|\.claude|\.git)\// { next }
    /^(_projects\.conf|_sync\.conf|_Dashboard\.md)$/ { next }
    /^_ClaudeSettings\// && !/^_ClaudeSettings\/(global|brain)\// { next }
    /^_Memory\/brain\/user_/ { next }
    /^_Memory\// && !/^_Memory\/brain\// { next }
    { print }
  '
}
```

Find what changed using the **local** commit hash (not the BrainShared commit). Use the **Bash** tool to run:

```bash
cd "$BRAIN"
if [ -n "${LAST_LOCAL_PUSH_COMMIT:-}" ]; then
  LOCAL_CHANGES=$(git diff --name-only "$LAST_LOCAL_PUSH_COMMIT" HEAD 2>/dev/null | filter_private)
else
  # First push — list all tracked files except private paths
  LOCAL_CHANGES=$(git ls-files 2>/dev/null | filter_private)
fi
```

### 3. Display Summary and Confirm

Group changes by category:

```
=== Local changes since last push ===

## Skills
_Skills/commit/SKILL.md
_Skills/push-brainshared/SKILL.md

## KnowledgeBase
_KnowledgeBase/Tauri.md

## Global Memories
_Memory/brain/feedback_testing.md

## Project: <slug>
_ActiveSessions/<slug>/_Status.md
_Memory/<slug>/<example-file>.md
```

If changes exist, display them and ask:

> "Push these changes to BrainShared (and project repos)? [Y/n]"

**Important:** Even if no local changes are detected, do NOT exit early. Continue to Step 4 to clone BrainShared and run the full diff/reverse scan in Step 6. The local change detection only catches files you modified — it cannot detect divergence between local and shared state (e.g., paths that exist on one side but not the other due to renames). Only exit with "Nothing to push. Your Brain is in sync." if Step 6 confirms local and remote are fully identical.

### 4. Clone BrainShared to Temp Dir

Use the **Bash** tool to run:

```bash
PUSH_TMP="/tmp/brainshared-push-$$"
echo "Cloning BrainShared..."
git clone --depth=50 "$SHARED_BRAIN_REMOTE" "$PUSH_TMP" 2>&1

if [ $? -ne 0 ]; then
  echo "FAIL: Could not clone $SHARED_BRAIN_REMOTE"
  rm -rf "$PUSH_TMP"
  exit 1
fi

REMOTE_HEAD=$(git -C "$PUSH_TMP" rev-parse HEAD)
```

Use `--depth=50` so there is enough history for diffs against `LAST_PUSH_COMMIT`.

### 5. Check If Partner Pushed New Changes

Use the **Bash** tool to run:

```bash
NEEDS_MERGE=false
if [ -n "${LAST_PUSH_COMMIT:-}" ] && [ "$REMOTE_HEAD" != "$LAST_PUSH_COMMIT" ]; then
  echo "Partner has pushed changes since your last push."
  REMOTE_CHANGES=$(git -C "$PUSH_TMP" diff --name-only "$LAST_PUSH_COMMIT" HEAD 2>/dev/null)
  echo "$REMOTE_CHANGES" | head -20
  NEEDS_MERGE=true
else
  echo "No partner changes to merge."
fi
```

### 6. Interactive Merge

Whether or not the partner pushed changes, always diff local vs shared and present findings interactively. The user decides what stays and what goes for every difference — nothing is auto-resolved silently.

#### Diff Algorithm

Compare the push temp dir (shared/remote state) against your local Brain for all non-private paths. Use the same `PRIVATE_PATTERN` exclusion from Step 2 to filter local files. Classify every file into one of these categories:

| Category | Local | Shared | What to show |
|---|---|---|---|
| **Identical** | exists | exists, same content | List as "no action needed" — don't ask |
| **Local only** | exists | doesn't exist | "You added this. Push to shared?" |
| **Shared only** | doesn't exist | exists | "Your partner added this. Keep or delete?" |
| **Both exist, differ** | exists | exists, different | Show diff. "Use yours, use theirs, or merge?" |
| **You deleted** | doesn't exist | exists (was in base) | "You deleted this. Remove from shared?" |
| **Partner deleted** | exists | doesn't exist (was in base) | "Your partner deleted this. Accept deletion or restore yours?" |

#### Stale Path Detection (Reverse Scan)

**Critical:** The forward diff (local → shared) only finds files that exist locally. It is blind to paths that exist in BrainShared but not locally (e.g., if a partner added something new, or if a rename left orphaned paths in the remote).

After the forward diff (local → shared), do a **reverse scan**:

1. List ALL tracked files in the shared repo (excluding `.gitignore`d paths):
   ```bash
   SHARED_ALL=$(git -C "$PUSH_TMP" ls-files | grep -v "^\.git")
   ```
2. For each file in the shared repo, check if it exists at the same path in local Brain
3. Files that exist in shared but NOT in local AND are not already covered by the forward diff → these are **stale paths** (renames, local deletions, or paths from a previous repo structure)
4. Present stale paths to the user: "These paths exist in BrainShared but not in your local Brain. They may be leftover from renames. Delete from shared?"
5. Give per-file or per-directory granularity — never silently keep or delete stale paths

#### Forward Scan (Local → Shared)

After the reverse scan, also check local non-private paths that don't exist in shared. These are files/directories you have locally that your partner doesn't have yet. Use the `PRIVATE_PATTERN` exclusion to filter. Use the **Bash** tool to run:

```bash
LOCAL_ALL=$(git -C "$BRAIN" ls-files | filter_private)
for file in $LOCAL_ALL; do
  if [ ! -e "$PUSH_TMP/$file" ]; then
    # Local-only — candidate for pushing to shared
  fi
done
```

#### Presenting Findings

Present findings **by top-level directory**, grouping files by their first path component. For each group, show:
- Identical file count: "12 files identical — no action needed"
- Files that differ: show the diff, ask per-file
- Shared-only or local-only: list them, ask per-file (keep/delete/push)

#### Per-File Decisions

For every non-identical file, use **AskUserQuestion** to ask:

**Shared-only files** (partner added or you deleted):
- **Keep** — leave it in the push dir
- **Delete** — remove from push dir (will be removed from shared)

**Local-only files** (you added or partner deleted):
- **Push** — copy to push dir
- **Skip** — don't include in this push

**Both exist, differ:**
- **Use mine** — overwrite shared with your local version
- **Use theirs** — keep the shared version
- **Merge** — combine both changes (AI proposes a merged version, user confirms)

When presenting diffs, use `diff -r` for skill directories and `diff` for individual files. Show enough context for the user to make an informed decision.

#### Merge Guidance by File Type

When the user chooses "merge" for files that differ on both sides:

1. **Skill files** (`_Skills/*/SKILL.md`): Section-level merge. If changes are in different sections, combine. If same section, show both and ask.
2. **KnowledgeBase files**: Entry-level merge. Different entries = combine. Same entry modified = show both, ask.
3. **Memory files** (`_Memory/brain/*.md`): Read frontmatter `name:`. Same name + different content = merge content, keep newer `description:`. Contradictory = ask.
4. **`MEMORY.md` index files**: Always auto-merge. Combine lines, deduplicate by filename, sort.
5. **Infrastructure/docs**: Show unified diff, let user choose or propose merged version.

#### Batching

You may group related decisions into a single `AskUserQuestion` (up to 4 questions per call). For example, present all shared-only skills in one question with a multi-select. But always give the user per-file granularity — never silently resolve.

### 7. Copy Merged Result to Push Dir

For each local change (and each merge resolution), use the **Bash** tool to copy the final version into the push temp directory:

```bash
for file in <resolved_files>; do
  rel_path="${file#$BRAIN/}"
  dest_dir="$PUSH_TMP/$(dirname "$rel_path")"
  mkdir -p "$dest_dir"
  cp "$BRAIN/$rel_path" "$PUSH_TMP/$rel_path"
done
```

For local deletions:
```bash
for file in <deleted_files>; do
  rm -f "$PUSH_TMP/$file"
done
```

### 8. Safety Check

Verify no private paths in the push directory. Use the **Bash** tool to run:

```bash
cd "$PUSH_TMP"
VIOLATION=$(git diff --name-only HEAD | grep -E "^(_Workbench/|_Profile/|_Agents/|_ActiveSessions/|_projects\.conf|_DevLog/|_AgentTasks/|_Dashboard\.md$|_sync\.conf$|_ClaudeSettings/(?!global/|brain/)|_Memory/brain/user_)" || true)
if [ -n "$VIOLATION" ]; then
  echo ""
  echo "SAFETY VIOLATION: Private paths detected in push:"
  echo "$VIOLATION"
  echo "Aborting. No changes pushed."
  rm -rf "$PUSH_TMP"
  exit 1
fi
```

### 9. Commit and Push to Main

Show merge summary:

```
=== Push summary ===
  Auto-merged: N files
  Conflict-resolved: N files  (if merge was needed)
  Your changes: N files added/modified
  Partner's changes: N files preserved

Ready to push to BrainShared main? [Y/n]
```

If yes:

Stage all changes in the push temp directory and commit directly. `/commit` is reserved for private Brain and solo projects — sync skills own their own commit logic.

**Commit hygiene (apply every time):**
- Verify local git identity is set (`git config user.name` / `user.email`). If missing, copy from the Brain repo's local config. Display "Committing as: Name <email>" before proceeding.
- Conventional Commits format: `sync(SYNC_IDENTITY): push YYYY-MM-DD`
- No Co-Authored-By, Signed-off-by, or AI attribution lines
- Subject line under 72 chars, imperative mood

Use the **Bash** tool to run:

```bash
cd "$PUSH_TMP"
git add -A
git commit -m "sync($SYNC_IDENTITY): push $(date +%Y-%m-%d)"
git push origin main
```

After push, record: `NEW_PUSH_COMMIT=$(git -C "$PUSH_TMP" rev-parse HEAD)`

**If push fails** (non-fast-forward — partner pushed between clone and push):

```bash
echo "Push rejected — partner may have pushed simultaneously. Retrying..."
git fetch origin main
git reset --hard origin/main
# Re-run merge algorithm against new remote HEAD
# Copy local changes again, resolve any new conflicts
git add -A
git commit -m "sync($SYNC_IDENTITY): push $(date +%Y-%m-%d)"
git push origin main
```

If it fails a second time:
> "Your partner may be pushing right now. Try again in a minute."

Clean up and exit.

### 10. Update _sync.conf

Write the updated sync state back to `_sync.conf`:

```bash
cat > "$SYNC_CONF" << 'SYNCEOF'
# BrainShared sync configuration
SHARED_BRAIN_REMOTE="<value>"
SHARED_BRAIN_BRANCH="<value>"
SHARED_ORG="<value>"
SYNC_IDENTITY="<value>"

# Updated automatically by /push-brainshared and /pull-brainshared
# Remote commits — for comparing against BrainShared state
LAST_PUSH_COMMIT="<new BrainShared commit>"
LAST_PUSH_DATE="<today>"
LAST_PULL_COMMIT="<preserved>"
LAST_PULL_DATE="<preserved>"

# Local commits — for git diff within the private Brain repo
LAST_LOCAL_PUSH_COMMIT="<local Brain HEAD after committing sync>"

SYNCEOF
```

Use the Write tool to rewrite the entire file with current values. Preserve all existing field values except the ones being updated (`LAST_PUSH_COMMIT`, `LAST_PUSH_DATE`, `LAST_LOCAL_PUSH_COMMIT`).

### 11. Commit to Private Brain

Stage `_sync.conf` and commit directly from the Brain directory. Same commit hygiene as Step 9 (identity check, Conventional Commits, no attribution). Suggested message: `sync: push to BrainShared YYYY-MM-DD`. Do not push — this is a local-only commit.

After committing, update `LAST_LOCAL_PUSH_COMMIT` in `_sync.conf` with the new local HEAD:
```bash
LAST_LOCAL_PUSH_COMMIT=$(git -C "$BRAIN" rev-parse HEAD)
```
Then rewrite `_sync.conf` with this value and amend the commit (or include it in the initial write if you write `_sync.conf` after the commit message is determined).

### 12. Clean Up

```bash
rm -rf "$PUSH_TMP"
echo ""
echo "=== Push complete ==="
echo "BrainShared: $SHARED_BRAIN_REMOTE ($NEW_PUSH_COMMIT)"
echo "Your partner can /pull-brainshared to get your changes."
```

## Output

[TBD]

## Rules

- Never push `_Workbench/`, `_Profile/`, `_Agents/`, `_ActiveSessions/`, `_projects.conf`, `_DevLog/`, `_AgentTasks/`, `_Dashboard.md`, `_sync.conf`, `_ClaudeSettings/<slug>/` (per-project) to BrainShared — enforce with safety check
- MEMORY.md index files are always auto-merged — never a conflict question
- If the safety check finds private paths, abort immediately
- Maximum 2 push retry attempts on race condition
- Never push without user confirmation
- Always update `_sync.conf` after a successful push
