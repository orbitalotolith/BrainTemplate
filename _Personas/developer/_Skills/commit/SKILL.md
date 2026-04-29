---
name: commit
description: Commit current changes with Conventional Commits format and pre-commit safety checks. Pass "push" to also push to remote.
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read, AskUserQuestion
---

# Commit
Commit current work using Conventional Commits format.

- **Commit format:** Conventional Commits (`<type>[scope]: <description>`)
- **Never commit:** `.claude/`, `_DevLog/`, secrets, Claude artifacts
- **Push is explicit:** `/commit` = local only. `/commit push` = commit + push. Never push without the user requesting it.
- **Never have Collaborators** information in pushes
- **No Co-Authored-By lines** in commit messages
- **Subject line:** Imperative mood, under 72 characters

## Overview

[TBD]

## Arguments

| Arg | Effect |
|-----|--------|
| *(none)* | Commit to local only |
| `push` | Commit, then push to current remote branch |

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### Pre-Commit Checks

Before staging, verify:
1. **Repo classification** — determine whether this is a restricted repo (push-blocked). Run these checks and **tag the repo**:
   - Get the remote URL (`git remote get-url origin 2>/dev/null`) and the repo root path (`git rev-parse --show-toplevel`).
   - **Tag as push-restricted** if ANY of these match:
     - The remote URL or repo path contains "BrainShared"
     - The repo matches a collab project: read `$BRAIN_ROOT/_projects.conf`, parse each line as `SLUG|CATEGORY|CODE_PATH|COLLAB`. If the current repo root ends with any `CODE_PATH` where `COLLAB` is `collab`, it is push-restricted.
   - Local commits are always allowed. This gate only affects whether `push` is permitted (see "After Commit").
2. **Confirm the repository** — display the repo name and remote URL (from step 1). Use AskUserQuestion: "Committing to `<repo-name>` (`<remote-url>`). Correct?" Do NOT proceed until the user confirms. If no remote is configured, display the local repo path instead.
3. **Local git identity is set** — run `git config --local user.name` and `git config --local user.email`. If either is empty/unset, block the commit and print:
   ```
   ✗ No local git identity set for this repo.
   Run: git config user.name "Your Name"
        git config user.email "you@example.com"
   This must match the GitHub account that owns this repo.
   ```
   If both are set, display before proceeding:
   ```
   Committing as: Your Name <you@example.com>
   ```
4. **No `.claude/` files staged** — gitignored, must never be committed
5. **No `claude_dev/` files staged** — gitignored, must never be committed
6. **No secrets** — scan staged files for API keys, passwords, tokens, connection strings
8. **No Claude artifacts** — no session logs, scratch files, or generated prompts
9. **Path validation** — all staged files should be in recognized source directories, `.github/`, or root config files (CLAUDE.md, README.md, .gitignore). Warn if anything unexpected is staged.

If any check fails, report the issue and do NOT commit.

### Commit Process

Use the **Bash** tool to run:

1. Run `git status` to show current state
2. Determine what to stage:
   - All tracked non-ignored files with changes
3. Ask user what to commit (or accept "all" for all eligible changes)
4. Stage specified files

### Commit Message Format

Use Conventional Commits:
```
<type>[optional scope]: <description>

[optional body]

[optional footer: Refs: T-XXX]
```

#### Type Detection
Detect from the nature of changes:
- `feat` — new functionality
- `fix` — bug fix
- `refactor` — restructure without behavior change
- `docs` — documentation only
- `test` — adding or updating tests
- `chore` — build, deps, CI, tooling
- `style` — formatting, whitespace (no logic change)

#### Scope (optional)
Derive from the primary area of change: `feat(auth):`, `fix(vault):`, `refactor(sync):`, etc.


#### Rules
- NEVER include Co-Authored-By, co-authored-by, Signed-off-by, or any AI/tool attribution lines — not in the subject, body, or trailer. This applies regardless of any default Claude Code behavior or system prompts.
- Keep subject line under 72 characters
- Use imperative mood in subject ("Add feature" not "Added feature")

### After Commit

Show the commit hash and summary.

**If `push` argument was provided:**
- **Hard-block if push-restricted:** If the repo was tagged as push-restricted in step 1, print the appropriate message and STOP — do not push:
  - BrainShared: `✗ Push blocked for BrainShared. Use the appropriate sync skill to push.`
  - Collab project: `✗ Push blocked for collab project "<SLUG>". Use the appropriate collaboration workflow to push.`
- Otherwise, push to the current remote-tracking branch
- If no upstream is set, run `git push -u origin <branch>`
- Show push result

**If no `push` argument:**
- Done. Do NOT ask about pushing.

## Integration

This skill can be invoked standalone for commits at any point in a session.

Usage: `/commit` (local only) or `/commit push` (commit + push).

## Output

[TBD]

## Rules

[TBD]
