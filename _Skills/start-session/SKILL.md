---
name: start-session
description: Start or continue a work session — load context from active session and project status
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read, AskUserQuestion
---

# Session Start

Load context from the vault and present a summary so work can resume.

## Overview

Locates the active session for the current working directory and presents a concise context summary so work can resume without re-reading files.

## Process

### 0. Read Gotchas

Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### 1. Resolve Project Slug

Use the **Bash** tool to resolve the Brain root and current working directory.

1. Read `$BRAIN/_projects.conf` (locate Brain root via `$BRAIN_ROOT` or by finding the nearest ancestor containing `_ActiveSessions/`).
2. Get CWD. Compute relative paths against `$BRAIN` and `~/Development/`.

3. Apply these resolution rules **in order** — first match wins:

   **a. Brain root itself:**
   If CWD == `$BRAIN`, slug = `brain`. No prompt.

   **b. Brain subdirs with slug in path (unambiguous):**
   Extract `<slug>` directly from the path for:
   - `$BRAIN/_ActiveSessions/<slug>/*`
   - `$BRAIN/_ActiveSessions/_Parked/<slug>/*`
   - `$BRAIN/_AgentTasks/<slug>/*`
   - `$BRAIN/_Memory/<slug>/*`
   - `$BRAIN/_DevLog/<slug>/*`
   - `$BRAIN/_Workbench/<slug>/*`
   - `$BRAIN/_ClaudeSettings/<slug>/*`

   No prompt — slug is determined by directory structure.

   **c. Code repo:**
   If CWD is under `~/Development/` but not under `$BRAIN`, match the relative path against `CODE_PATH` entries from the registry (longest prefix wins). The matching `SLUG` is the project slug. No prompt.

   **d. Cross-cutting Brain subdirs (ambiguous — prompt):**
   For these areas, work could apply to any project, so **use AskUserQuestion** to ask which project's session to load:
   - `$BRAIN/_Skills/*`
   - `$BRAIN/_KnowledgeBase/*`
   - `$BRAIN/_Profile/*`
   - `$BRAIN/_Agents/*`
   - `$BRAIN/` (any other path that doesn't match a-c above)

   Options: all slugs from `_projects.conf` (with `brain` pre-selected as default), plus `none — exit`.

   **e. No match:**
   Output: "No project found for this directory. Add an entry to `_projects.conf` and create `_ActiveSessions/<slug>/`." — then stop.

### 1b. Collab Symlink Safety

If the resolved slug is a collab project (4th field of `_projects.conf` is `collab`), verify the code repo's `project_files/brain/` entries are symlinks, not real files. If any are real files, a prior `git pull` outside `/pull-projectshared` corrupted them — refuse to start so we don't present stale content.

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

### 2. Load Context

Read these two files (skip any that don't exist):

- `$BRAIN/_ActiveSessions/<slug>/session.md` — handoff, current state, next steps
- `$BRAIN/_ActiveSessions/<slug>/_Status.md` — current focus, active decisions, gotchas

### 2b. Count Status Entries

If `_Status.md` was loaded, count entries in Active Decisions and Gotchas sections. Caps:

- Active Decisions: 25
- Gotchas: 10

If either is over its cap, note it — a 1-line warning will be prepended to the context summary in step 3.

### 3. Present

Concise summary, 20 lines max:

- If counts are over cap, prepend: `⚠ _Status.md has N decisions (cap 25) / M gotchas (cap 10) — consider /status-audit`
- **Last handoff** — what was being worked on, where it left off, next steps, code state
- **Active decisions** — names only, from `_Status.md`
- **Gotchas** — all, from `_Status.md`

### 4. Prompt

Use **AskUserQuestion** to ask: "Continue from where you left off, or start something new?"

## Rules

- Read-only — does not modify any files
- Only loads session.md and _Status.md — everything else (CLAUDE.md, memories, KB) is handled by the system or other skills
- No git operations — no pull, no status, no sync
- If a file doesn't exist, skip it silently and present what's available

## Output

A concise context summary (≤20 lines):
- **Last handoff** — what was being worked on, where it left off, next steps, code state
- **Active decisions** — names only, from `_Status.md`
- **Gotchas** — all items from `_Status.md`
- A prompt: "Continue from where you left off, or start something new?"
