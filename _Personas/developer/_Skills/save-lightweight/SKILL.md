---
name: save-lightweight
description: Checkpoint session state quickly — session handoff, git state, and timestamp only. Use when you want a fast save without the full knowledge sweep of /save-session.
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit
---

# Lightweight Save

## Overview

Fast checkpoint: update session handoff, verify git state, write timestamp. No knowledge sweep, no KB, no memory, no profile, no CLAUDE.md updates. Use `/save-session` for full knowledge capture.

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.

### 1. Resolve Project

```bash
BRAIN="${BRAIN_ROOT:-}"
if [ -z "$BRAIN" ]; then
  BRAIN=$(dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null)
fi
grep -v '^#' "$BRAIN/_projects.conf" | grep -v '^$'
```

Resolution rules **in order** — first match wins:

- **a. Brain root itself** — CWD == `$BRAIN` → slug = `brain`. No prompt.
- **b. Brain subdirs with slug in path (unambiguous)** — extract `<slug>` from: `_ActiveSessions/<slug>/*` (or `_Parked/<slug>/*`), `_AgentTasks/<slug>/*`, `_Memory/<slug>/*`, `_DevLog/<slug>/*`, `_Workbench/<slug>/*`, `_ClaudeSettings/<slug>/*`.
- **c. Code repo** — CWD under `~/Development/` but not `$BRAIN` → match CODE_PATH (longest prefix wins).
- **d. Cross-cutting Brain subdirs (ambiguous — prompt)** — for `_Skills/*`, `_KnowledgeBase/*`, `_Profile/*`, `_Agents/*`, or any other Brain path not matching a-c, use **AskUserQuestion** to ask which project. Options: all slugs from `_projects.conf` (default: `brain`) + "none — cancel".
- **e. No match** — stop with error.

AS file: `$BRAIN/_ActiveSessions/<slug>/session.md`.

### 1b. Collab Symlink Safety

If the resolved slug is a collab project (4th field of `_projects.conf` is `collab`), verify the code repo's `project_files/brain/` entries are symlinks, not real files. If any are real files, a prior `git pull` outside `/pull-projectshared` corrupted them — refuse to save so we don't clobber fresh Brain canonical with stale repo copies.

```bash
COLLAB=$(grep "^${slug}|" "$BRAIN/_projects.conf" | cut -d'|' -f4)
if [ "$COLLAB" = "collab" ]; then
  code=$(grep "^${slug}|" "$BRAIN/_projects.conf" | cut -d'|' -f3)
  repo_brain="$HOME/Development/$code/project_files/brain"
  broken=""
  for item in CLAUDE.md session.md _Status.md memory DevLog Workbench _AgentTasks; do
    t="$repo_brain/$item"
    [ -e "$t" ] && [ ! -L "$t" ] && broken="$broken $item"
  done
  if [ -n "$broken" ]; then
    echo "ERROR: Brain symlinks are broken in $slug (collab repo)."
    echo "       Real files at:$broken"
    echo "       Fix: /pull-projectshared (merges partner changes + restores symlinks)"
    echo "       Or:  _setup.sh (only if Brain canonical is known-fresh)"
    exit 1
  fi
fi
```

### 2. Detect Format and Identity

```bash
if [ "$slug" = "brain" ]; then SESSION_FORMAT="legacy"; else SESSION_FORMAT="universal"; fi
source "$BRAIN/_sync.conf" 2>/dev/null
IDENTITY="${SYNC_IDENTITY:-$(hostname -s)}"
```

### 3. Verify Git State

Run in the **project directory** (CWD), not Brain:

```bash
git status --short
git log --oneline -5
```

Also check commits since last save:

```bash
LAST_SAVE=$(cat ~/.claude/last-session-save-timestamp 2>/dev/null || echo "0")
git log --oneline --since="@$LAST_SAVE" --author="$(git config user.name)" 2>/dev/null
```

### 4. Update Session File

Read the existing session file. Make minimal updates only:

**Universal format:** Find `## $IDENTITY |` section. Update `**Current:**` line and the date on the section header. Do NOT touch the partner's section.

**Legacy format:** Update `updated:` frontmatter date. Append a 1-line update to `## Handoff` context if anything new happened since last save. Do NOT overwrite the file.

If the AS file doesn't exist, create it with the full format from `/save-session` step 3.

### 4b. Append Summary to _Status.md

Take the `**Current:**` line content (the session summary sentence) and append it to `_Status.md` under a `## Recent Sessions` section. If the section doesn't exist, create it at the bottom of the file.

Format each entry as:
```
- YYYY-MM-DD HH:MM — <current line content>
```

Keep only the last 5 entries in this section (drop the oldest if needed). Do NOT touch any other section of `_Status.md`.

### 4c. Capture New Gotchas *(via /capture)*

Scan the conversation since last save for **new gotchas** the user or Claude encountered — platform quirks, framework surprises, workarounds discovered, landmines to avoid next time.

- If **none surfaced**: skip this step silently.
- If **at least one surfaced**: for each, invoke `/capture` in interactive mode (NOT silent):

```
/capture gotcha "<1-line description>" --slug=<slug>
```

`/capture` interactive mode confirms each entry via `AskUserQuestion` before writing, appends with `(YYYY-MM-DD)` date prefix, and emits the ⚠ cap-warning line if `## Gotchas` exceeds 10 or `## Active Decisions` exceeds 25.

This is **capture only** — no routing to KB/CLAUDE.md/skills/memory. Routing is owned by `/status-audit` and happens deliberately, not mid-save.

### 5. Write Timestamp

```bash
date +%s > ~/.claude/last-session-save-timestamp
```

### 6. Token Tracking

Maintain a running character count of all Read outputs, Write/Edit inputs, and Bash outputs during this save. Compute: `estimated_tokens = total_chars / 4`.

## Output

```
Lightweight save:
  Handoff: _ActiveSessions/<slug>/session.md [updated | created]
  Status: _ActiveSessions/<slug>/_Status.md [Recent Sessions updated]
  Committed: N commits since last save [or "none"]
  Uncommitted: [list or "clean"]
  Token estimate: ~X,XXX tokens (reads: ~X chars, writes: ~X chars, bash: ~X chars, skill: ~2K chars)
```

## Rules

- **Minimal knowledge capture only.** This skill skips memories, KB, profile, and CLAUDE.md. The only exception is appending the session summary to `_Status.md ## Recent Sessions` (last 5 entries). Use `/save-session` for full knowledge capture.
- **Never overwrite existing handoff content** — append or update in place only.
- **Never touch the partner's section** in universal format files.
- **Code state from git output only** — never from session memory.
- **Never mention committing in output** — that's the user's choice.
