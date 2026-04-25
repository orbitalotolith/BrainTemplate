---
name: create-project
description: Use when creating a new development project or onboarding an existing project into the Brain vault. Run from anywhere under ~/Development/<Category>/.
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Create Project

Scaffolds a new project and wires it fully into the Brain vault: git, CLAUDE.md, Brain notes, symlink, and memory sync. Supersedes `project-init`.

## Overview

[TBD]

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### 1. Gather Context

Detect from CWD:
- Strip `~/Development/` prefix and the project directory name from the path; the remaining middle segments are the category (e.g. `~/Development/Clients/Acme/MyApp` → category = `Clients/Acme`, `~/Development/Personal/MyApp` → category = `Personal`)
- If CWD is not under `~/Development/`, ask the user where this project lives

Use AskUserQuestion to gather:
- **Project name** (PascalCase, e.g. `MyProject`)
- **Brief description** (one sentence for CLAUDE.md + _Status.md)

First, detect Brain root. Use the **Bash** tool to run:

```bash
BRAIN="${BRAIN_ROOT:-}"
if [ -z "$BRAIN" ]; then
  BRAIN=$(dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null)
fi
if [ -z "$BRAIN" ]; then
  echo "ERROR: Cannot locate Brain root."
  exit 1
fi
DEV="$HOME/Development"
```

Derive:
- `SLUG` = lowercase project name, no spaces (e.g. `myproject`)
- `REPO_DIR` = `$DEV/<Category>/<Subcategory>/<ProjectName>`

---

### 2. Scaffold the Code Repo

Skip any sub-step if the file/directory already exists (never overwrite).

Use the **Bash** tool to run:

```bash
mkdir -p $REPO_DIR
cd $REPO_DIR
git init          # skip if already a git repo
```

Create `.gitignore` (skip if exists). Solo repos ignore all of `project_files/brain/` (symlinks to Brain):
```
.claude/
project_files/brain/
```
Add language-specific entries if the tech stack is known.

Create `project_files/data/` directory. Use the **Bash** tool to run:

```bash
mkdir -p $REPO_DIR/project_files/data
```

Create `CLAUDE.md` (skip if exists). Read `templates.md` companion file for the "CLAUDE.md Scaffold" template.

**Note:** If the project will have platform-specific frontends, add a `clients/` section to the structure. Ask the user about target platforms. See `_HowThisWorks.md` "Universal Project Structure" for the full layout.

---

### 3. Register in Project Registry

Use the **Edit** tool to add one line to `$BRAIN/_projects.conf` (the single source of truth for all project mappings):

```
<SLUG>|<Category>|<Category>/<Subcategory>/<ProjectName>|<collab>
```

Where `<Category>` is informational (e.g. `Lab`, `Clients/Acme`) and `<collab>` is empty for solo repos or `collab` for shared repos.

All consumers (`_setup.sh`, `_health-check.sh`, `save-session`, `start-session`) read from this file automatically — no other files need updating.

---

### 4. Create Brain Structure (canonical — real files)

Brain holds all real files. Create them first. Use the **Bash** tool to run:

```bash
# Directories
mkdir -p "$BRAIN/_ClaudeSettings/$SLUG"
mkdir -p "$BRAIN/_Memory/$SLUG"
mkdir -p "$BRAIN/_ActiveSessions/$SLUG"
mkdir -p "$BRAIN/_DevLog/$SLUG"
mkdir -p "$BRAIN/_Workbench/$SLUG"
mkdir -p "$BRAIN/_Docs/$SLUG/Plans" "$BRAIN/_Docs/$SLUG/Reports"
```

Use the **Bash** tool to copy the project CLAUDE.md:

```bash
cp "$REPO_DIR/CLAUDE.md" "$BRAIN/_ClaudeSettings/$SLUG/CLAUDE.md"
```

Use the **Write** tool to create `$BRAIN/_Memory/$SLUG/MEMORY.md`:

```
# Memory Index
```

Use the **Write** tool to create `$BRAIN/_ActiveSessions/$SLUG/session.md`. Read `templates.md` companion file for the "session.md Template".

Use the **Write** tool to create `$BRAIN/_ActiveSessions/$SLUG/_Status.md`. Read `templates.md` companion file for the "_Status.md Template".

---

### 5. Create Symlinks via `_setup.sh`

Run `_setup.sh` to create all symlinks. It reads `_projects.conf` (updated in step 3) and creates the correct `project_files/brain/` symlinks, Claude Code memory symlinks, and root `CLAUDE.md` chain for the new project. Use the **Bash** tool to run:

```bash
bash "$BRAIN/_setup.sh"
```

The `_Workbench/` directory is where all project notes, research, and working documents go. Any existing loose notes should be moved here during onboarding.

---

### 6. Verify

Use the **Bash** tool to run:

```bash
bash "$BRAIN/_health-check.sh"
```

All checks should pass (or show WARN for the symlink if the repo directory didn't exist before step 2 — acceptable).

---

### 7. Commit Brain Changes

Use the **Bash** tool to run:

```bash
cd "$BRAIN"
git add _ActiveSessions/<SLUG>/ \
        _ClaudeSettings/<SLUG>/ \
        _Memory/<SLUG>/ \
        _DevLog/<SLUG>/ \
        _Workbench/<SLUG>/ \
        _Docs/<SLUG>/ \
        _projects.conf
git commit -m "feat(vault): add <ProjectName> project"
```

---

### 8. Handoff

Tell the user:

> "**<ProjectName> is ready.** Run `/save-session` to capture this session, then open a new terminal and run:
> ```bash
> cd "$DEV/<Category>/<ProjectName>" && claude
> ```
> Start that session with `/start-session` to load context."

---

## Output

[TBD]

## Rules

- Never overwrite existing files — skip and note what was skipped
- If the code repo already exists (e.g. retroactively onboarding), skip Steps 2a-2c but still complete Steps 3–8
- `_projects.conf` is the single source of truth — one line per project, all consumers read it
- Brain holds all real files; code repos get symlinks pointing into Brain
- All repos start as solo (`project_files/brain/` gitignored). To share, update `_projects.conf` collab flag.
