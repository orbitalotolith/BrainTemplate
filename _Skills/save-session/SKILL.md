---
name: save-session
description: Save full session context so work can resume in a fresh session without losing anything
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Session Save

Capture everything needed to resume this session's work from scratch in a fresh conversation. This is a save point — the next Claude session should be able to pick up exactly where this one left off with zero context loss.

See CLAUDE.md "Workflow Conventions" for standard paths.

## Overview

[TBD]

## Arguments

| Flag | Description |
|------|-------------|
| `--push` | Force a Brain git commit and push regardless of save tier — use when you want brain changes pushed immediately without waiting for Obsidian Git |
| `--ff-only` | git pull mode used in Step 2b when pulling Brain git before writing — aborts if history has diverged |
| `--short` | git status display flag used in Steps 2d and 11 to show a compact uncommitted-changes summary |
| `--oneline` | git log display flag used in Steps 1c and 11 to show a compact list of recent commits |

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### 1. Review the Full Session

Before writing anything, mentally walk through the entire conversation to extract:

- **What was the goal?** — What the user set out to do this session
- **What got done?** — Completed tasks, features implemented, bugs fixed, files created/modified
- **What's partially done?** — In-progress work: what's been done so far vs what remains
- **Decisions made** — Why approach A was chosen over B, trade-offs considered, user preferences expressed
- **Problems hit and how they were solved** — Errors, dead ends, workarounds, things that didn't work and why
- **Understanding gained** — How a system works, architectural insights, gotchas discovered, patterns identified
- **Current exact state** — What file/function/line was being worked on, what state the code is in (compiles? tests pass? half-refactored?)
- **What should happen next** — Immediate next steps, ordered by priority

Be thorough. Anything not written down here will be lost.

### 1b. Classify the Save (Two Tiers)

This skill runs frequently — speed comes from deferring narration, never from skipping knowledge capture.

```bash
LAST_SAVE=$(cat ~/.claude/last-session-save-timestamp 2>/dev/null || echo "0")
```

| Tier | When | What Runs |
|------|------|-----------|
| **Standard** | Default for every save. | Scan conversation since last save for new knowledge. Write anything found (memories, KB, profile, CLAUDE.md). Update AS file (append or overwrite). Sync memories (8b). Verify git state. Timestamp + git status. ~5-15s when knowledge found, faster when nothing new. |
| **Substantial** | Session produced work worth narrating — features completed, bugs fixed, architectural decisions, meaningful understanding gained. | Everything in Standard, PLUS: full session review (step 1), DevLog archiving (2c), full AS rewrite with detailed narration, log.md maintenance (5), Brain git commit offer (9). |

**Classification is content-based, not time-based.** The question is: "Has anything worth narrating in detail happened since last save?" not "How long since last save?"

- If conversation since last save has no new tool calls, no new code, no new decisions → standard save confirms nothing new, writes timestamp + git status (fast)
- If conversation has new work (minor or major) → standard save captures the knowledge
- If session produced substantial work worth archiving → substantial save with full narration

Default to standard. Only escalate to substantial when the session genuinely warrants a DevLog entry.

### Project Resolution

Before any read or write, determine which AS file belongs to this project:

1. Read the project registry: `$BRAIN/_projects.conf`
   ```bash
   # Locate Brain root
   BRAIN="${BRAIN_ROOT:-}"
   if [ -z "$BRAIN" ]; then
     BRAIN=$(dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null)
   fi
   if [ -z "$BRAIN" ]; then
     echo "ERROR: Cannot locate Brain root. Run _setup.sh or set BRAIN_ROOT in your shell config."
     exit 1
   fi
   DEV="$HOME/Development"
   # Parse registry into slug|category|code triples
   grep -v '^#' "$BRAIN/_projects.conf" | grep -v '^$'
   ```
2. Get CWD. Strip `~/Development/` prefix to get the relative path.
3. Match against CODE_PATH entries from the registry (longest prefix wins). The matching SLUG is the project slug.
4. If CWD is under `$BRAIN/_Workbench/<slug>/`, extract `<slug>` directly.
5. If no match, warn: "No active session file found for this project. Run `/create-project` to register it."

The AS file path is: `$BRAIN/_ActiveSessions/<slug>/session.md`

### 1d. Detect Project Format and Identity

```bash
# Brain-canonical: all projects except brain use universal format
# Brain holds the real files; code repos have symlinks to Brain
if [ "$slug" = "brain" ]; then
  SESSION_FORMAT="legacy"
else
  SESSION_FORMAT="universal"
fi

# Read identity for session.md section headers
source "$BRAIN/_sync.conf" 2>/dev/null
IDENTITY="${SYNC_IDENTITY:-$(hostname -s)}"
```

For the `brain` slug, always use `SESSION_FORMAT="legacy"` (Brain has no code repo).

### 1c. Identify Session Commits

Determine what was committed since the last save:

```bash
LAST_SAVE=$(cat ~/.claude/last-session-save-timestamp 2>/dev/null || echo "0")
git log --oneline --since="@$LAST_SAVE" --author="$(git config user.name)" 2>/dev/null
```

This works without `/start-session` — it uses the `last-session-save-timestamp` that every save writes (step 10). Cap display at 20 commits. If more exist, show "...and N more" with the full range.

Include these commits in the session review (step 1) — they represent work completed and committed since the last save point.

### 2b. Pull Brain Git Before Writing

Before modifying any vault files, pull the latest Brain git to detect conflicts early:

```bash
cd "$BRAIN" && git pull --ff-only 2>&1
```

If pull fails (merge conflict or diverged history):
1. Show the error to the user
2. Do NOT proceed with writing to `_ActiveSessions/<slug>/session.md`
3. Suggest: "Brain git has diverged. Run `cd \"$BRAIN\" && git pull` and resolve conflicts before saving."

If pull succeeds (or remote is unreachable — offline work is fine), continue with the save.

### 2c. Archive Previous Handoff *(substantial sessions only)*

Skip this step entirely for lightweight sessions — a quick cleanup isn't worth a DevLog entry.

For substantial sessions: before overwriting the AS file:

1. Read `$BRAIN/_ActiveSessions/<slug>/session.md`
2. If the file has an existing `## Handoff` section, copy it to the DevLog archive:
   - File: `$BRAIN/_DevLog/<slug>/YYYY-MM-DD.md` (Brain-canonical — all DevLogs live in Brain)
   - If the file exists (same-day save), append under a `## Previous Handoff (archived)` heading
   - If the file doesn't exist, create it with the full DevLog format (see below)
3. If the AS file doesn't exist yet, skip archiving (it will be created in step 3)

**DevLog format** (`$BRAIN/_DevLog/<slug>/YYYY-MM-DD.md`):

```markdown
# YYYY-MM-DD — [1-line summary]

## Session Goal
[What the user set out to do]

## What Got Done
- [Specifics with file paths]

## Decisions Made
- [Decision]: [Full reasoning, trade-offs considered]

## Problems & Solutions
- [Problem] → [How it was resolved / why approach X failed]

## Understanding Gained
- [Architectural insights, system behavior discovered]
```

Create the `$BRAIN/_DevLog/<slug>/` directory if it doesn't exist.

### 2d. Verify Project Git State

Before writing the handoff, verify the actual state of the project repo. Run these in the **project directory** (CWD), not Brain:

```bash
git status --short
git log --oneline -5
```

Capture this output — it populates the "Code state" line in step 3. Do not write "Code state" from session memory. The output of step 1c (commits since last save) can supplement this but does not replace it.

### 3. Update Session File

The session file path depends on format detected in step 1d:
- **Legacy:** `$BRAIN/_ActiveSessions/<slug>/session.md`
- **Universal:** The symlink target of `$BRAIN/_ActiveSessions/<slug>/session.md` (which is `project_files/brain/session.md` in the code repo)

**If `SESSION_FORMAT="legacy"` (including "brain" slug):**

Proceed with the existing single-person format — write the entire file as below.

**If `SESSION_FORMAT="universal"` (session.md):**

1. Read the existing `session.md` file
2. Find the section matching `## $IDENTITY |` (your identity header)
3. If your section exists, replace it entirely (from your `## identity |` line to the next `## ` line or end of file)
4. If your section doesn't exist, append it after the last section

The replacement section format for substantial saves:

```markdown
## <IDENTITY> | <YYYY-MM-DD>

**Current:** <1-line summary of current state>

### Handoff
- **Left off:** [file:function, state of code]
- **What got done:** [brief list of completed items]
- **Next:** [immediate action to take]
- **Context:** [anything non-obvious — gotchas, temp state, blockers]
- **Code state:** [verified from step 2d output]
```

For standard saves: find your section's `**Current:**` line and update it. Update the date on your section header. Do not touch the partner's section.

**CRITICAL:** Never overwrite the partner's section. Read the file, find section boundaries by `## ` headers, replace only YOUR section.

---

**Legacy format details:**

This file belongs entirely to this project. Write the whole file — no shared state to preserve.

**Standard saves:** Do NOT overwrite the existing file. The existing handoff is still accurate. Append a brief update to the `## Handoff` section's "What got done" or "Context" bullet if anything new happened. At minimum, update the `updated:` frontmatter date to confirm the save ran.

**Substantial saves — write the full file:**

```markdown
---
tags: [active-session]
project: <ProjectName>
status: active
updated: <YYYY-MM-DD>
last-saved-by: <$(hostname -s)>
---

# <ProjectName>

**Current:** <1-line summary of current state>

## Handoff
- **Left off:** [file:function, state of code]
- **What got done:** [brief list of completed items]
- **Next:** [immediate action to take]
- **Context:** [anything non-obvious — gotchas, temp state, blockers]
- **Code state:** [verified from step 2d output — see format below]
```

**Parking a project:** Move the directory to `_Parked/`:
```bash
cd "$BRAIN" && git mv _ActiveSessions/<slug> _ActiveSessions/_Parked/<slug>
```
Update the frontmatter `status:` to `parked` and add `parked-reason:` field.

**Unparking:** `git mv _ActiveSessions/_Parked/<slug> _ActiveSessions/<slug>` and set `status: active`.

**Code state format:** Populate entirely from step 2d's verified git output. For build/test status, qualify with the last commit where it was verified — do not assert current state from memory.

```
- **Code state:** Tests passed as of abc1234. Verified: 3 commits on main since last save, 2 files uncommitted.
```

If the AS file doesn't exist yet (new project, first save), create it with the format above.

### 4. Update `_Status.md` *(only if something changed)*

The _Status.md file lives at `$BRAIN/_ActiveSessions/<slug>/_Status.md` (Brain-canonical). Code repos access it via symlink at `project_files/brain/_Status.md`.

Skip this step if slug is `brain` (Brain's own status is different).

Skip this step if current focus, decisions, and gotchas are all unchanged from before this session.

If anything changed, edit `_Status.md` in place — do NOT append:

- **Current Focus** — update to reflect what's actively being worked on
- **Active Decisions** — living list of key decisions with 1-line reasoning. Max ~10 entries. When a decision is revisited, REPLACE the entry — don't add a duplicate. When a decision is reversed, remove the old entry and add the new one.
- **Gotchas** — things that will bite you if you don't know them. REMOVE entries when the gotcha is fixed. Add new ones discovered this session.
- **Version** — update if version changed
- **Overview / Tech Stack** — update only if meaningfully changed

**Size rule:** Target 40-80 lines. If exceeding ~100 lines, move detail into `project_files/brain/Architecture/` or similar subdocs and leave a pointer.

### 5. Update Project Documentation *(if something new was learned)*

Runs on every save. Skip only if no new patterns, conventions, or gotchas were discovered since last save.

If something was learned:
- **CLAUDE.md** — add any new patterns, conventions, or gotchas. These persist across all future sessions, so anything learned about the codebase that's generally useful belongs here.
- **README.md** — update if new features or setup steps were added

### 7.5. Update `_KnowledgeBase/` *(if platform-level knowledge was discovered)*

Runs on every save. Skip only if all discoveries were project-specific or nothing new was learned since last save.

Write to `$BRAIN/_KnowledgeBase/` if this session surfaced:
- A platform or tool bug/quirk (Xcode, Swift, Rust library, build tool, OS behavior)
- A framework API behavior applicable to any project using that technology
- A gotcha that would bite a developer new to this technology

**How to write:** Find the matching file by topic (BLE.md, iOS Development.md, etc.). Append to the Gotchas section or add a new section. Include version/context on every entry (e.g., "as of Xcode 16.2", "bluer 0.15+"). If no file matches the topic, create one with frontmatter `tags: [reference, <domain>]`.

**How to prune:** When writing, scan the same file for existing entries that are now resolved, superseded, or no longer apply. Remove them. A lean KB beats an exhaustive one.

**Do NOT write to KB:** Project-specific bugs, codebase decisions, or repo-only patterns. Those go in `_Status.md` Gotchas or project `CLAUDE.md`.

### 8. Write to Claude Memory *(if preferences or feedback emerged)*

Runs on every save. Skip only if no user preferences, feedback on Claude's behavior, or cross-project patterns were observed since last save.

If any of the following occurred, write to Claude's memory system (`~/.claude/projects/<project>/memory/`):

- **User preferences or feedback** on Claude's behavior → save as `feedback` type memory
- **Cross-project patterns** ("user always wants X") → save as `user` type memory
- **Workflow preferences** ("user prefers short responses") → save as `user` type memory

**Do NOT save to memory:** Project-specific decisions (→ `_Status.md`), code patterns (→ `CLAUDE.md`), session history (→ DevLog).

### 8c. Update `_Profile/` *(if session revealed new profile info)*

Runs on every save. Skip only if nothing since last save revealed new information about the user — their preferences, business state, skills, or identity. When in doubt, skip.

If something was revealed, update the relevant file in `$BRAIN/_Profile/`:

- **New preference or feedback about how they work with AI** → `preferences.md`
- **Business update** (new client, revenue change, new service, LLC update) → `business.md`
- **New skill or tool demonstrated/mentioned** → `skills.md`
- **Identity or philosophy shift** → `identity.md`

Edit in place — do NOT append duplicate entries. Replace outdated information rather than duplicating it. Update the `updated:` frontmatter date on any file you modify.

**What belongs here vs Claude Memory:**
- **Claude Memory** (`~/.claude/projects/.../memory/`) — fast cross-session recall, project-scoped, ephemeral
- **`_Profile/`** — authoritative human-readable record, synced cross-machine via Brain git, visible in Obsidian, persists indefinitely
- Both can be updated in the same session when relevant — they serve different access patterns

### 8d. Update `_Agents/oto/` *(if session revealed new oto behavior or standing context)*

Runs on every save. Skip if nothing since last save changed how oto — the chief-of-staff agent — should behave or what it should know at startup. When in doubt, skip. User preferences (tone, working style) belong in `_Profile/` — step 8c covers that.

If something was revealed, update the relevant file in `$BRAIN/_Agents/oto/`:

- **Persona change** (tone, voice, personality traits, "never" rules) → `persona.yaml` — YAML fields only, no markdown
- **Behavioral constraint** ("oto should route X via Y", "always ask before Z") → create or edit `constraints.md` with a brief list
- **New pointer or convention oto should know at startup** → `standing-context.md`

Edit in place. Never overwrite the full persona.yaml just to update one field. This file is symlinked into AgentDashboard (`AgentDashboard/skills/oto/persona.yaml → _Agents/oto/persona.yaml`), so changes take effect on next oto restart.

**Do NOT write to `_Agents/oto/memory/`** — that's oto's private scratchpad, written by the agent itself via `vault_write`.

### 8b. Sync Memory Back to Brain Git *(every save — even if no new memories were written)*

Verify that Claude memory and Brain `_Memory/` are in sync for each project.

With Brain-canonical architecture, Claude memory (`~/.claude/projects/<path>/memory/`) is a symlink to `$BRAIN/_Memory/<slug>/` for all non-brain projects. This means any memory Claude writes goes directly into Brain — no copy needed.

For the `brain` slug (copy-based sync since Brain has no code repo):

```bash
BRAIN="${BRAIN_ROOT:-}"
if [ -z "$BRAIN" ]; then
  BRAIN=$(dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null)
fi
prefix=$(echo "$HOME" | tr '/' '-' | sed 's/^-//')
brain_name=$(basename "$BRAIN")
suffix="Development-$brain_name"
src="$HOME/.claude/projects/-${prefix}-$suffix/memory"
dest="$BRAIN/_Memory/brain"
if [ -d "$src" ] && [ ! -L "$src" ] && [ -d "$dest" ]; then
  cp -f "$src/"*.md "$dest/" 2>/dev/null
fi
```

For all other projects, verify the symlink is valid:

```bash
while IFS='|' read -r slug category code collab; do
  [[ "$slug" =~ ^#.*$ || -z "$slug" ]] && continue
  [ "$slug" = "brain" ] && continue
  suffix="Development-$(echo "$code" | tr '/' '-')"
  claude_mem="$HOME/.claude/projects/-${prefix}-$suffix/memory"
  brain_mem="$BRAIN/_Memory/$slug"
  if [ -L "$claude_mem" ]; then
    actual=$(readlink "$claude_mem")
    if [ "$actual" = "$brain_mem" ]; then
      continue  # Valid symlink — no action needed
    fi
  fi
  # Symlink missing or wrong — warn
  echo "WARN: $slug Claude memory not symlinked to Brain. Run _setup.sh."
done < "$BRAIN/_projects.conf"
```

Brain is the authoritative source for ALL project memories. `_setup.sh` creates the symlinks on each machine.

### 9. Commit and Push Brain Git *(substantial only — or explicit override)*

- **Standard saves:** Skip. Obsidian Git handles background sync.
- **Substantial saves:** Check for changes and offer to commit and push as below.
- **Override:** If the user explicitly requests `--push` or says "save and commit brain", commit regardless of tier.

For substantial saves (or overrides), check the Brain git repo for uncommitted changes:

```bash
cd "$BRAIN" && git status --short
```

If there are changes (e.g. `_ActiveSessions/`, `_KnowledgeBase/`, `_Workbench/`, `_Memory/`), use `AskUserQuestion` to ask whether to commit and push. **If the user agrees, invoke `/commit push` (the commit skill) to handle the commit.** Never commit directly with raw git commands — `/commit push` is the single path for all git commits, including Brain vault commits during `/save-session`.

**Why this matters:** Brain notes are also synced via Obsidian Git, but that only runs when Obsidian is open. If the user is working in terminal-only mode, Brain changes won't reach the remote without this step. Without a pushed Brain, the next machine gets stale context.

Do NOT auto-commit — offer and wait for confirmation. If the user declines, note that vault changes will sync when Obsidian Git next runs.

### 9b. Final Memory Sync *(catch-all)*

Re-run the same memory sync from step 8b. This catches any memories written during the commit flow (step 9) — e.g., user feedback triggered by `/commit` interactions. Skips automatically if nothing new was written since 8b (cp -f is idempotent).

```bash
# Same script as 8b — re-run to catch late-written memories
```

### 10. Mark Session Saved

Write the current Unix timestamp to `~/.claude/last-session-save-timestamp`. This tells the Stop hook that a save occurred, suppressing "unsaved session" alerts for the next hour.

Run: `date +%s > ~/.claude/last-session-save-timestamp`

### 11. Git Status *(all tiers)*

Show two sections — what was committed since last save, and what's still uncommitted:

```
Committed since last save: N commits
  abc1234 feat(auth): add token refresh
  def5678 fix(api): handle null response

Uncommitted changes:
  M src/utils/format.ts
  ?? src/new-file.ts
```

If no commits since last save, show "Committed: none". If no uncommitted changes, show "Uncommitted: clean".

For substantial saves, the AS file's **Code state** line is populated from step 2d — not from this step's output. See step 3 for the verified format.

## Output

### Token Tracking

Throughout execution, maintain a running count of **characters read and written** across all tool calls during this save. This includes:
- All file contents returned by Read tool calls
- All file contents passed to Write/Edit tool calls
- All Bash command outputs
- The skill text itself (~19,000 chars)

At the end, compute: `estimated_tokens = total_chars / 4` (rough approximation).

Report the breakdown in the output as shown below.

**Standard/Substantial save:**
```
Session saved [standard | substantial]:
  Handoff: _ActiveSessions/<slug>/session.md updated (compact handoff for <project>)
  Archived: project_files/brain/DevLog/YYYY-MM-DD.md [created | appended | skipped (standard)]
  Status: project_files/brain/_Status.md [updated | skipped (no changes)]
  CLAUDE.md: [updated with X | skipped (nothing new learned)]
  KB: _KnowledgeBase/<file>.md [updated: <finding>, pruned N stale | created: <file> | skipped (project-specific only)]
  Memory: [wrote N memories | skipped (no preferences/feedback observed)]
  Profile: _Profile/<file>.md [updated: <what changed> | skipped (nothing new learned)]
  Oto: _Agents/oto/<file> [updated: <what changed> | skipped (no oto-behavior or standing-context changes)]
  Brain git: [committed + pushed | declined (Obsidian Git will sync) | skipped (standard) | no changes]
  Plan: X/Y tasks complete, T-XXX in progress [if plan exists]
  Committed: N commits since last save [or "none"]
  Uncommitted: [list or "clean"]
  Next session: [1-line summary of what to do first]
  ---
  Token estimate: ~X,XXX tokens (reads: ~X,XXX chars, writes: ~X,XXX chars, bash: ~X,XXX chars, skill: ~19K chars)
```

## Rules

- **Knowledge capture is the priority.** The goal of every save is to ensure the AI continuously improves its understanding of WHY and HOW decisions are made. Speed is achieved by deferring narration (DevLog, full AS rewrite), not by skipping learning (memories, KB, profile, CLAUDE.md).
- **State claims require verification.** The handoff distinguishes two kinds of claims: *action claims* ("updated 6 skills", "chose approach A") are immutable and can be written from session memory. *State claims* ("compiles", "tests pass", "files uncommitted") decay the moment another actor touches the repo. State claims must be either verified at write-time (run the command) or explicitly qualified with when they were last verified (e.g., "tests passed as of commit abc1234"). Never assert current state from memory alone.
- **Every save runs knowledge capture.** Steps 3 (AS update), 4 (_Status.md), 6 (CLAUDE.md), 7.5 (KB), 8 (memories), 8b (sync), 8c (profile), 8d (oto), 9b (final sync), 10 (timestamp), 11 (git status) run on every save. They skip only if nothing new was found — never because of tier.
- **Tier classification is content-based.** "Has anything worth narrating happened?" — not "How long since last save?"
- For standard saves: skip DevLog archiving (2c), log.md (5), full session review narration (1), and Brain git commit (9). Always run knowledge capture and memory sync.
- For substantial saves: run the full pipeline including session review, DevLog, and Brain git commit offer.
- Default to standard. Only escalate to substantial when the session genuinely warrants a DevLog entry.
- Never overwrite the AS file for a standard save — the existing handoff reflects real active work that may be ongoing
- Write handoff notes from the perspective of someone who has zero context
- Include file paths, function names, and specifics — not vague summaries
- Don't auto-commit — always use AskUserQuestion to confirm
- Each project has its own AS file at `_ActiveSessions/<slug>/session.md` — write the whole file directly (no shared state)
- Keep handoff sections compact (10-20 lines) — detailed context goes in DevLog and `_Status.md`
- EDIT `_Status.md` in place — replace outdated entries, don't append duplicates
- EDIT `_Profile/` subfiles in place — never overwrite wholesale, update specific entries only
- This skill works at any point in a session
- **Never mention committing in "Next" or "Next session" lines.** Committing is the user's choice — don't suggest it as a next step regardless of whether commits were made this session or not. Focus next-session notes on the actual work to continue.
