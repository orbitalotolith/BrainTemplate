---
name: pull-skills
description: Pull latest skills from BrainShared and update key-to-dev.md skill reference
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Skill, AskUserQuestion
---

# Pull Skills

Pull latest skills from BrainShared `_Skills/` into the local vault. Additive merge — new and updated skills are pulled in, local-only skills are preserved.

## Overview

[TBD]

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### 1. Pre-check

Detect vault root (directory containing `_ActiveSessions/`). Fail if not in vault.

Read `_sync.conf` to get the BrainShared remote. Use the **Bash** tool to run:

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

if [ -z "$SHARED_BRAIN_REMOTE" ]; then
  echo "SHARED_BRAIN_REMOTE must be set in _sync.conf"
  exit 1
fi
BRANCH="${SHARED_BRAIN_BRANCH:-main}"
```

Check for uncommitted changes in `_Skills/`. Use the **Bash** tool to run:

```bash
git diff --name-only -- _Skills/
git diff --cached --name-only -- _Skills/
```

If changes exist, use **AskUserQuestion** to warn: "You have uncommitted changes in _Skills/. Updated skills from BrainShared will overwrite local edits to matching skills. Local-only skills are safe. Proceed or abort?"

### 2. Snapshot local state

Before fetching, record which skills exist locally:
```bash
ls -d _Skills/*/  # list local skill directories
```

### 3. Fetch from BrainShared

```bash
PULL_TMP="/tmp/brainshared-skills-pull-$$"
echo "Fetching skills from BrainShared..."
git clone --depth=1 --branch "$BRANCH" "$SHARED_BRAIN_REMOTE" "$PULL_TMP" 2>&1

if [ $? -ne 0 ]; then
  echo "FAIL: Could not clone $SHARED_BRAIN_REMOTE"
  echo "Check your SSH keys and remote URL in _sync.conf"
  rm -rf "$PULL_TMP"
  exit 1
fi
```

### 4. Merge skills (additive)

List all skills in BrainShared's `_Skills/`:
```bash
ls -d "$PULL_TMP/_Skills/"/*/
```

For each skill directory in BrainShared:
- Read the SKILL.md content from the cloned repo
- If the skill directory doesn't exist locally, create it (`mkdir -p _Skills/<name>`)
- Compare content with local version (if exists). Track status:
  - **new** — skill didn't exist locally, now added
  - **updated** — skill existed but content differs, overwritten with BrainShared version
  - **unchanged** — skill exists and content matches BrainShared exactly
- Write the BrainShared version to `_Skills/<name>/SKILL.md`
- Also copy any companion files (other .md files in the skill directory)

Skills that exist locally but NOT in BrainShared are **local-only** — do not touch them.

**CRITICAL: Never delete local skills. Never push to BrainShared.**

### 5. Clean up

```bash
rm -rf "$PULL_TMP"
```

### 6. Update key-to-dev.md

Read every `_Skills/*/SKILL.md` and extract `name` and `description` from frontmatter.

Use the **Edit** tool to update the current `key-to-dev.md` skill tables. Preserve existing category assignments and "When" column values. Add new skills to the category that best fits their description. Remove entries for skills that no longer exist.

### 7. Present summary

Show a table to the user:

```
## Pull Skills Summary

| Skill | Status |
|-------|--------|
| commit | unchanged |
| save-session | updated |
| new-cool-skill | new |
| my-custom-skill | local-only |
```

Then show the full skill list with descriptions (all skills, not just changed ones).

If any skills were added, highlight them with their descriptions so the user knows what's new.

## Output

[TBD]

## Rules

- **Never push to BrainShared.** This is a read-only pull.
- **Never delete local skills.** The merge is additive only.
- **Always read the remote from _sync.conf.** Never hardcode a remote URL.
- **Always update key-to-dev.md** after merging so the reference stays current. Read existing categories from key-to-dev.md at runtime — never hardcode category assignments.
- **Run from vault root only.** Fail early if `_ActiveSessions/` is not found in the working directory.
