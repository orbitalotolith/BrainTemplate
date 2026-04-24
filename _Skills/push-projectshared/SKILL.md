---
name: push-projectshared
description: For project collaboration repos — push latest changes (code + brain context) to the project's shared partner repo
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, AskUserQuestion, Skill
---

# Push Project Shared

## Overview

For collab repos: review and push all changes — code commits AND brain context files — to the shared repo. Brain symlinks are temporarily replaced with real content for the push, then restored. Partners pull real files, never symlinks.

**Run from:** The project's code repo directory.

## Arguments

| Flag | Description |
|------|-------------|
| `--ff-only` | git pull mode used in Step 4 — aborts if the pull cannot fast-forward, forcing manual conflict resolution |
| `--no-assume-unchanged` | git update-index flag used in Step 5 to clear skip flags on brain files before staging |
| `--assume-unchanged` | git update-index flag used in Step 11 to re-mark brain symlinks so git skips working-tree checks |

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory before proceeding.

### 1. Project Resolution

Use the **Bash** tool to run:

```bash
BRAIN="${BRAIN_ROOT:-}"
if [ -z "$BRAIN" ]; then
  BRAIN=$(dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null)
fi
DEV="$HOME/Development"
```

1. Read `$BRAIN/_projects.conf`
2. Get CWD, strip `~/Development/` prefix
3. Match against CODE_PATH entries (longest prefix wins) → SLUG, CATEGORY, CODE_PATH, COLLAB
4. If no match: "Not a registered project. Run `/create-project` to register it."
5. If slug is `brain`: "Use `/push-brainshared` for Brain vault changes."
6. If COLLAB is not `collab`: "This is a solo repo. Use `/commit` for standard git operations."

### 2. Detect Brain Root and Read Sync Config
- Auto-detect `BRAIN_ROOT` via `_ActiveSessions`
- Source `_sync.conf`, parse `SHARED_PROJECTS` array for this slug
- Extract `LAST_PUSH_COMMIT` and `LAST_PULL_COMMIT` for this project (if entry exists)

### 3. Fetch Remote and Detect Partner Changes

Use the **Bash** tool to run:

```bash
cd "$repo"
git fetch origin
REMOTE_HEAD=$(git rev-parse origin/main)
REMOTE_URL=$(git remote get-url origin)
```

**If LAST_PUSH_COMMIT does not exist** (first push) OR **LAST_PUSH_COMMIT is not in history** (`git cat-file -t "$LAST_PUSH_COMMIT"` fails — stale baseline):
- If stale: warn "LAST_PUSH_COMMIT not found in history — treating as first push"
- Set `NEEDS_MERGE=true` and `FULL_REVIEW=true` (all remote brain files treated as partner changes)
- `PARTNER_CHANGES=$(git diff --name-only HEAD origin/main -- project_files/brain/)`

**If LAST_PUSH_COMMIT exists** and `REMOTE_HEAD != LAST_PUSH_COMMIT`:
- `PARTNER_CHANGES=$(git diff --name-only "$LAST_PUSH_COMMIT" origin/main -- project_files/brain/)`
- Show partner's brain file changes
- Set `NEEDS_MERGE=true`

**If REMOTE_HEAD == LAST_PUSH_COMMIT**: no partner changes. `NEEDS_MERGE=false`.

### 3b. Detect Code Changes

Count commits ahead of remote and check for uncommitted code changes:

```bash
cd "$repo"
CODE_COMMITS_AHEAD=$(git rev-list --count origin/main..HEAD)
UNCOMMITTED=$(git status --short -- ':!project_files/brain/' ':!*.xcuserstate')
```

### 3c. Display Changes Summary and Confirm

Show a unified summary of everything being pushed — code and brain context — before any mutations:

```
=== Changes to push: <slug> ===
Remote: <remote-url>

## Code commits (N ahead of origin/main)
<git log --oneline origin/main..HEAD, max 30 lines>

## Uncommitted code changes (will NOT be pushed)
<git status --short, excluding brain/ and xcuserstate>

## Brain context files
<list of brain files that will be synced>

## Partner changes
<none | N brain files changed by partner — merge needed>
```

Use `git log --oneline --no-decorate origin/main..HEAD | head -30` for the commit list. If more than 30, show the count and note how many are truncated.

If uncommitted code changes exist, warn clearly: **"These files are NOT committed and will not be pushed. Use `/commit` first if you want to include them."**

Use **AskUserQuestion** to confirm: "Push N code commits + brain context to origin/main?"
- **Push all** — proceed with push
- **Cancel** — abort, restore symlinks

If there are no code commits ahead AND no brain changes, exit: "Nothing to push. Local and remote are in sync."

### 4. Git Pull
**assume-unchanged flags remain SET** — git skips working-tree checks for brain files, allowing pull to succeed even though symlinks differ from committed real files.

Use the **Bash** tool to run:

```bash
git pull --ff-only
```
If fails (not fast-forward): abort, tell user to resolve code conflicts first. Do NOT clear assume-unchanged (they're still set, which is the normal state).

### 5. Clear assume-unchanged flags

Use the **Bash** tool to run:

```bash
cd "$repo"
for f in project_files/brain/CLAUDE.md project_files/brain/session.md \
         project_files/brain/_Status.md project_files/brain/memory \
         project_files/brain/DevLog project_files/brain/Workbench; do
  git update-index --no-assume-unchanged "$f" 2>/dev/null || true
done
```

### 6. Dereference — Replace symlinks with real content

For each shared file, temporarily replace the symlink with real file content. Use the **Bash** tool to run:

```bash
brain_dir="$repo/project_files/brain"

# CLAUDE.md
rm "$brain_dir/CLAUDE.md"
cp "$BRAIN/_ClaudeSettings/$SLUG/CLAUDE.md" "$brain_dir/CLAUDE.md"

# session.md
rm "$brain_dir/session.md"
cp "$BRAIN/_ActiveSessions/$SLUG/session.md" "$brain_dir/session.md"

# _Status.md
rm "$brain_dir/_Status.md"
cp "$BRAIN/_ActiveSessions/$SLUG/_Status.md" "$brain_dir/_Status.md"

# memory/ — replace symlink with real directory copy
rm "$brain_dir/memory"
mkdir -p "$brain_dir/memory"
cp -R "$BRAIN/_Memory/$SLUG/"* "$brain_dir/memory/" 2>/dev/null

# DevLog/ — replace symlink with real directory copy
rm "$brain_dir/DevLog"
mkdir -p "$brain_dir/DevLog"
cp -R "$BRAIN/_DevLog/$SLUG/"* "$brain_dir/DevLog/" 2>/dev/null

# Workbench/ — replace symlink with real directory copy
rm "$brain_dir/Workbench"
mkdir -p "$brain_dir/Workbench"
cp -R "$BRAIN/_Workbench/$SLUG/"* "$brain_dir/Workbench/" 2>/dev/null
```

Check each source exists before copying (graceful skip if a Brain dir is empty).

### 7. Brain File Merge (partner changes only)

**Skip this step if `NEEDS_MERGE=false`.** The user already confirmed the push in Step 3c.

If `NEEDS_MERGE=true` (partner changed brain files OR first push/stale baseline):
- For each brain file that partner changed:
  - Show unified diff between partner's committed version and your dereferenced version
  - **session.md:** Auto-merge by identity sections (different `## identity` sections = combine; same section = prefer local)
  - **MEMORY.md index:** Auto-merge (combine lines, deduplicate, sort)
  - **All other files:** Use **AskUserQuestion** to ask per-file: "Use yours / Use theirs / Merge"
  - For "Merge": AI proposes merged version, user confirms

### 8. Safety Check

Before staging, verify:
- Only `project_files/brain/` files will be staged (excluding `_Docs`)
- No `.claude/` files
- No secrets — AI reads the staged diff and flags anything that looks like a credential (API keys, tokens, passwords, private keys)
- Staged files are all in expected brain paths

ABORT if violation found.

### 9. Pre-commit Checks and Commit

Push-projectshared owns the full commit (does NOT invoke `/commit`). Follows the same hygiene (based on `/commit` as source of truth for git practices):
1. Verify local git identity (`git config user.name` / `user.email`) — block if missing
2. Display repo name and remote URL, confirm with user
3. Stage brain files:
   ```bash
   git add project_files/brain/ -- ':!project_files/brain/_Docs'
   ```
4. Commit with Conventional Commits format:
   - Suggested: `docs(brain): sync shared context YYYY-MM-DD`
   - No Co-Authored-By, no attribution lines
   - Subject under 72 chars, imperative mood
5. Push to remote:
   ```bash
   ALLOW_COLLAB_PUSH=1 git push origin main
   ```
6. **Race condition:** If push fails (non-fast-forward), fetch + pull --ff-only + re-stage + retry. Max 2 attempts.

### 10. Restore Symlinks

After push completes (or fails), use the **Bash** tool to restore symlinks:

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

### 11. Set assume-unchanged flags

Use the **Bash** tool to run:

```bash
cd "$repo"
for f in project_files/brain/CLAUDE.md project_files/brain/session.md \
         project_files/brain/_Status.md project_files/brain/memory \
         project_files/brain/DevLog project_files/brain/Workbench; do
  git update-index --assume-unchanged "$f" 2>/dev/null || true
done
```

### 12. Update Sync State

Update `_sync.conf` SHARED_PROJECTS entry for this slug:
```
SLUG|REMOTE_URL|NEW_PUSH_COMMIT|LAST_PUSH_DATE|LAST_PULL_COMMIT|LAST_PULL_DATE
```
Where `NEW_PUSH_COMMIT = $(git rev-parse HEAD)`.

Use Write tool to rewrite `_sync.conf`, preserving all other entries.

## Output

```
=== Push Project Shared: <slug> ===
Remote: <remote-url>
Code commits pushed: N
Partner brain changes: [N files merged | none | first push — full review]
Brain files pushed: N
Brain commit: <hash>
Symlinks: restored
```

## Rules

- Only for collab repos (COLLAB=collab in _projects.conf). Solo repos use /commit.
- Always dereference before commit, restore symlinks after — even if push fails or is cancelled
- Always set assume-unchanged after restoring symlinks
- If interrupted between dereference and restore: `_setup.sh` detects real files and recreates symlinks
- Shared files: CLAUDE.md, session.md, _Status.md, memory/, DevLog/, Workbench/
- Never push _Docs — those are Brain-only content
- Push-projectshared owns its own git commit — never invoke `/commit`
- assume-unchanged flags remain SET during git pull; clear only after pull completes
