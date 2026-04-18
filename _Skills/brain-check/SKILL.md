---
name: brain-check
description: Run _setup.sh to fix symlinks and seed memories, then _health-check.sh to validate vault integrity. Quick structural validation — run before /push-brainshared or when things feel off.
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read
---

# Brain Check

**Run from:** Any directory. Brain root is auto-detected via `$BRAIN_ROOT`. No CWD dependency.

Run `_setup.sh` and `_health-check.sh` in sequence. This is the fast structural validation step — fixes symlinks, seeds memories, then verifies the entire vault is wired correctly.

**When to run:**
- Before `/push-brainshared` (minimum pre-push validation)
- After creating a new project or cloning a repo
- After pulling Brain git on a new machine
- When a skill or memory isn't showing up
- When something feels off

## Overview

[TBD]

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### 1. Detect Brain Root

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

### 2. Run _setup.sh

Use the **Bash** tool to run:

```bash
echo "=== Running _setup.sh ==="
bash "$BRAIN/_setup.sh"
```

This is idempotent and safe to re-run. It:
- Writes `BRAIN_ROOT` to shell config (if not set)
- Creates note symlinks for each project in `_projects.conf`
- Symlinks `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, `~/.claude/skills/` to Brain
- Seeds project memories from `_Memory/` into `~/.claude/projects/`

If setup fails, show the error and stop — don't run health check on a broken setup.

### 3. Run _health-check.sh

Use the **Bash** tool to run:

```bash
echo ""
echo "=== Running _health-check.sh ==="
bash "$BRAIN/_health-check.sh"
```

This validates:
- Core directories and files exist
- Project note symlinks resolve
- Claude config symlinks point to correct targets
- Memory files are in sync between Brain and `~/.claude/`
- All memory subdirectories are registered in `_projects.conf`
- No orphaned project directories
- ActiveSession file coverage
- Hardcoded Brain directory names in infrastructure scripts (should use `$BRAIN`/`$BRAIN_ROOT`)
- Empty `_ClaudeSettings/` subdirectories (migration artifacts)
- WordOfWisdom integrity (headings present in CLAUDE.md)
- Sync config validation (required fields, staleness, shared project registration)

### 4. Report

If health check passed with 0 failures:

> "Brain is healthy. Safe to `/push-brainshared`."

If warnings only (e.g., repos not cloned, no push recorded):

> "Brain is healthy with N warnings (informational). Safe to `/push-brainshared`."

If failures:

> "Brain has N failures. Fix the issues above before pushing. Most can be resolved by re-running `_setup.sh` or registering missing projects with `/create-project`."

## Output

[TBD]

## Rules

- Always run `_setup.sh` before `_health-check.sh` — setup fixes issues that health check would otherwise report
- Do not modify any files — this skill is read-only validation (setup is the only exception, and it's idempotent)
- If either script fails with an error exit, stop and show the error — don't silently continue
