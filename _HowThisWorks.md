# How This Vault Works

## Purpose

This document is written for AI agents. If you are an AI reading this, this file tells you everything you need to understand, operate within, or replicate this vault's structure.

Brain is the persistent memory layer for all development work. It lives at `$BRAIN_ROOT/` and is always cloned on every machine. Code repos are temporary — clone to work, push, delete. Notes never go away.

### Companion Documents

Three documents guide this system. Each has a distinct audience:

| Document | Audience | Purpose |
|----------|----------|---------|
| `_HowThisWorks.md` | AI agents | Full vault architecture — structure, conventions, replication guide |
| `key-to-dev.md` | Humans | Development workflow quick reference — skills, daily workflows, setup |
| `WordOfWisdom.md` | Both | Foundational principles that govern all AI behavior in this system |

`_HowThisWorks.md` describes **what the structure is**. `key-to-dev.md` describes **how to use it day-to-day**. `WordOfWisdom.md` describes **why** — the non-negotiable principles (Honesty, Security, Sources, Done Means Done) that every AI operating in this vault must follow. The Word of Wisdom is also embedded in the global `CLAUDE.md` so it loads into every Claude Code session automatically.

---

## Folder Layout

```
~/Development/
├── <Brain>/                       <- Obsidian vault root + Brain git repo
│   ├── WordOfWisdom.md                 <- foundational AI behavior principles
│   ├── _HowThisWorks.md               <- THIS FILE (AI agent guide)
│   ├── key-to-dev.md                   <- human workflow quick reference
│   ├── _Dashboard.md                   <- Dataview project overview
│   ├── _projects.conf                  <- single source of truth for all project mappings
│   ├── _setup.sh                       <- symlink + Claude config setup for new machines
│   ├── _health-check.sh               <- vault integrity verification script
│   │
│   ├── _ActiveSessions/               <- per-project session + status directories
│   │   ├── brain/                    <- Brain's own session + status (real files)
│   │   │   ├── session.md
│   │   │   └── _Status.md
│   │   ├── project1/                 <- REAL files (canonical)
│   │   │   ├── session.md           <- real file (code repo symlinks here)
│   │   │   └── _Status.md           <- real file (code repo symlinks here)
│   │   ├── project2/                 <- REAL files (canonical)
│   │   │   ├── session.md           <- real file (code repo symlinks here)
│   │   │   └── _Status.md           <- real file (code repo symlinks here)
│   │   └── _Parked/                   <- parked (inactive) project sessions
│   │
│   ├── _Profile/                       <- user identity, skills, business context (AI-readable)
│   │   ├── index.md                   <- entry point — overview + pointers
│   │   ├── identity.md               <- education, background, philosophy
│   │   ├── business.md               <- business state, clients, services
│   │   ├── skills.md                  <- languages, platforms, expertise
│   │   └── preferences.md            <- communication style, working patterns
│   │
│   ├── _Memory/                        <- Claude memories
│   │   ├── brain/                     <- global memories (tracked in Brain git, shared via BrainShared)
│   │   │   ├── MEMORY.md
│   │   │   └── *.md
│   │   ├── project1/                  <- REAL directory (canonical; code repo symlinks here)
│   │   ├── project2/                  <- REAL directory (canonical; code repo symlinks here)
│   │   └── project3/                  <- REAL directory (canonical; code repo symlinks here)
│   │
│   ├── _KnowledgeBase/                 <- cross-project technical knowledge
│   │   ├── TopicA.md
│   │   ├── TopicB.md
│   │   └── TopicC.md
│   │
│   ├── _Skills/                        <- single source of truth for custom Claude skills
│   │   ├── start-session/SKILL.md
│   │   ├── save-session/SKILL.md
│   │   ├── commit/SKILL.md
│   │   └── ...                        <- custom skills (see key-to-dev.md for full list)
│   │
│   ├── _Agents/                        <- runtime agents that consume Brain (distinct from _projects.conf)
│   │   ├── README.md                   <- convention + read/write scopes
│   │   └── <agent-name>/
│   │       ├── persona.yaml           <- identity, personality, constraints (canonical; agent runtime symlinks here)
│   │       ├── standing-context.md    <- startup brief — pointers into the vault
│   │       └── memory/                 <- agent's private notes (writable by the agent)
│   │
│   ├── _Templates/                     <- Obsidian note templates (Templater syntax)
│   ├── _Workbench/                      <- per-project scratch space (real directories)
│   │   ├── project1/                 <- REAL directory (canonical; code repo symlinks here)
│   │   └── project2/                 <- REAL directory (canonical; code repo symlinks here)
│   │
│   ├── _ClaudeSettings/               <- ~/.claude/ source of truth (symlinked on setup)
│   │   ├── global/                    <- global config (symlinked to ~/.claude/ on setup)
│   │   │   ├── CLAUDE.md             <- global Claude instructions
│   │   │   └── settings.json         <- plugins, model, permissions
│   │   └── <slug>/                   <- per-project CLAUDE.md (real files, canonical)
│   │
│   ├── _DevLog/                       <- per-project session history (real directories, canonical)
│   └── _Docs/                         <- implementation specs, plans, audit reports, workflow logs
│       ├── <slug>/                    <- per-project docs (accessed via <Project>/_Docs symlink)
│       │   ├── Plans/                 <- implementation plans
│       │   └── Reports/               <- audit reports (code-audit, security-audit, skill-audit)
│
├── <Category>/                         <- any number of top-level categories
│   └── <Subcategory>/                  <- optional grouping (e.g., client name, topic)
│       └── <Project>/                  <- temporary code repos (clone when needed)
│           ├── CLAUDE.md
│           ├── core/                   <- backend / shared logic
│           ├── clients/                <- platform-specific frontends (when multi-platform)
│           │   ├── web/
│           │   ├── macos/
│           │   ├── ios/
│           │   ├── desktop/            <- Tauri/Electron (wraps web for Linux/Windows)
│           │   └── shared/             <- shared client code (Swift package, shared types)
│           ├── test/                   <- all tests (plural `tests/` also acceptable; follows language convention)
│           ├── config/                 <- app configuration that ships
│           ├── .claude/                (gitignored)
│           └── project_files/          (development support — never shipped)
│               ├── brain/              <- SYMLINKS to Brain (canonical files live in Brain)
│               │   ├── CLAUDE.md       <- SYMLINK -> <Brain>/_ClaudeSettings/<slug>/CLAUDE.md
│               │   ├── _Status.md      <- SYMLINK -> <Brain>/_ActiveSessions/<slug>/_Status.md
│               │   ├── session.md      <- SYMLINK -> <Brain>/_ActiveSessions/<slug>/session.md
│               │   ├── memory          <- SYMLINK -> <Brain>/_Memory/<slug>/
│               │   ├── DevLog          <- SYMLINK -> <Brain>/_DevLog/<slug>/
│               │   ├── Workbench       <- SYMLINK -> <Brain>/_Workbench/<slug>/
│               │   └── _Docs           <- SYMLINK -> <Brain>/_Docs/<slug>/ (gitignored)
│               ├── data/               <- runtime data, databases, generated files (gitignored)
│               ├── assets/             <- design files, source images (gitignored)
│               └── tools/              <- dev scripts, utilities (gitignored)
```

**Note:** Brain holds all real files for per-project metadata. `_ActiveSessions/<slug>/` directories contain real `session.md` and `_Status.md` files. `_Memory/<slug>/`, `_Workbench/<slug>/`, `_DevLog/<slug>/`, and `_ClaudeSettings/<slug>/` are real directories in Brain. Code repos contain only symlinks pointing into Brain via `project_files/brain/`. Category grouping is preserved as a `CATEGORY` field in `_projects.conf` and a `category` field in each project's `_Status.md` frontmatter for Dataview queries.

Not every project needs all subdirectories shown above — start with `_Status.md` and add directories as needed.

---

## Replicating This Structure

If you are an AI agent and your user wants to adopt this system, here is how to create the structure from scratch. Copy the directory layout — not the content. Content is personal.

### Step 1: Create the vault

```bash
mkdir -p ~/Development/<BrainName>
cd ~/Development/<BrainName>
git init
```

### Step 2: Create core directories

```bash
mkdir -p _ActiveSessions/_Parked
mkdir -p _Profile
mkdir -p _Memory/brain
mkdir -p _KnowledgeBase
mkdir -p _Skills
mkdir -p _Templates
mkdir -p _Workbench           # per-project scratch space (real directories)
mkdir -p _ClaudeSettings
mkdir -p _DevLog
```

### Step 3: Create foundational files

These files must exist for the system to function:

| File | Purpose | Create How |
|------|---------|------------|
| `WordOfWisdom.md` | AI behavior principles | Write principles that match the user's values |
| `_HowThisWorks.md` | This file — vault architecture | Copy this template, adapt to the user's setup |
| `key-to-dev.md` | Human workflow reference | Write after skills are configured |
| `_Dashboard.md` | Obsidian Dataview overview | Create with Dataview queries for project status |
| `_projects.conf` | Single source of truth for project mappings | One `SLUG|CATEGORY|CODE_PATH|COLLAB` line per project |
| `_setup.sh` | New-machine setup script | Reads `_projects.conf`, creates symlinks (ActiveSessions, Workbench, memories, Claude config) |
| `_health-check.sh` | Vault integrity checks | Reads `_projects.conf`, validates symlinks, memories, coverage |
| `_ClaudeSettings/global/CLAUDE.md` | Global Claude instructions | Write — embed Word of Wisdom, vault conventions |
| `_ClaudeSettings/global/settings.json` | Claude Code config | Write — plugins, permissions, model preferences |
| `_Profile/index.md` | User identity entry point | Collaborate with user to capture who they are |
| `_Memory/brain/MEMORY.md` | Global memory index | Start empty — memories accumulate over time |

### Step 4: Memories — copy, merge, or start fresh

When a user already has Claude memories from another system:

- **Copy**: Bring all existing memory files into `_Memory/brain/`. Preserve as-is.
- **Merge**: Read existing memories. Deduplicate. Resolve conflicts (edits come from multiple sources). Write merged result.
- **Start fresh**: Create empty `MEMORY.md` index files. Memories build naturally through sessions.

Ask the user which approach they prefer. Memory files use this format:

```markdown
---
name: <memory name>
description: <one-line description>
type: <user|feedback|project|reference>
---

<content>
```

### Step 5: Connect projects

For each code project the user wants to integrate:

1. Add one line to `<Brain>/_projects.conf`: `<slug>|<category>|<code-path>|<collab>`
2. Create Brain directories: `_ActiveSessions/<slug>/`, `_Memory/<slug>/`, `_ClaudeSettings/<slug>/`, `_DevLog/<slug>/`, `_Workbench/<slug>/`, `_Docs/<slug>/` with real files
3. Run `_setup.sh` to create symlinks from code repo `project_files/brain/` into Brain

---

## New Machine Setup

```bash
# 1. Clone Brain (all real files — session, status, memory, CLAUDE.md — are in Brain git)
git clone git@github.com:<user>/Brain.git ~/Development/Brain

# 2. Clone code repos (only what you're working on)
git clone git@github.com:... ~/Development/<Category>/<Subcategory>/<Project>

# 3. Run setup (creates symlinks: code repo project_files/brain/ -> Brain, ~/.claude/ config)
cd ~/Development/Brain && bash _setup.sh

# 4. Open Obsidian -> open vault -> select $BRAIN_ROOT/
# 5. Enable plugins: Dataview, Templater, Obsidian Git
```

---

## How Symlinks Work

Brain holds all real files for per-project metadata. Code repos contain only symlinks pointing INTO Brain for access.

### Brain-Canonical Architecture

Brain is the single source of truth for all project context. Every project's session, status, memory, CLAUDE.md, DevLog, and Workbench files live as real files in Brain directories. Code repos access them via symlinks in `project_files/brain/`.

```
<Brain>/                                           <- REAL files (canonical, tracked in Brain git)
├── _ActiveSessions/<slug>/session.md              <- real file
├── _ActiveSessions/<slug>/_Status.md              <- real file
├── _ClaudeSettings/<slug>/CLAUDE.md               <- real file
├── _Memory/<slug>/                                <- real directory
├── _DevLog/<slug>/                                <- real directory
├── _Workbench/<slug>/                             <- real directory
├── _Docs/<slug>/                                  <- real directory
```

```
<Code Repo>/                                       <- SYMLINKS (point to Brain)
├── CLAUDE.md                                      <- symlink -> project_files/brain/CLAUDE.md
├── project_files/
│   └── brain/
│       ├── CLAUDE.md    -> <Brain>/_ClaudeSettings/<slug>/CLAUDE.md
│       ├── session.md   -> <Brain>/_ActiveSessions/<slug>/session.md
│       ├── _Status.md   -> <Brain>/_ActiveSessions/<slug>/_Status.md
│       ├── memory       -> <Brain>/_Memory/<slug>/
│       ├── DevLog       -> <Brain>/_DevLog/<slug>/
│       ├── Workbench    -> <Brain>/_Workbench/<slug>/
│       └── _Docs        -> <Brain>/_Docs/<slug>/
```

```
~/.claude/projects/<path-key>/memory/              <- symlink -> <Brain>/_Memory/<slug>/
```

These code repo symlinks are machine-specific (absolute paths differ per machine). They are NOT committed to the code repo's git — solo repos gitignore `project_files/brain/` entirely. `_setup.sh` creates them. `_health-check.sh` validates them.

### What stays as real files in Brain

Everything. All per-project metadata is canonical in Brain:

- `_ActiveSessions/<slug>/session.md` and `_Status.md` — real files, tracked in Brain git
- `_ClaudeSettings/<slug>/CLAUDE.md` — real file, tracked in Brain git
- `_Memory/<slug>/` — real directory, tracked in Brain git
- `_DevLog/<slug>/` — real directory, tracked in Brain git
- `_Workbench/<slug>/` — real directory, tracked in Brain git
- `_Memory/brain/` — global memories, real files, tracked in Brain git

### Why this direction

- **Complete backup:** Brain git contains everything. Clone Brain on a new machine and all project context is immediately available — no code repos needed.
- **Obsidian visibility:** All notes are real files in the vault. Obsidian renders them directly — no dangling symlinks when repos aren't cloned.
- **Consistency:** One format for all projects. `_setup.sh` and `_health-check.sh` enforce it.
- **Claude access:** Claude reads `project_files/brain/` directly from CWD via symlinks. Claude memory dir symlinks to Brain's `_Memory/<slug>/`.
- **Collaboration:** For collab repos, `push-projectshared` temporarily dereferences symlinks into real files for commit/push. Partners always pull real files, never symlinks.

### When a code repo isn't cloned

Code repo symlinks are the only things that break when a repo isn't cloned — and they're machine-local, created by `_setup.sh`. Brain still has all real files, visible in Obsidian and tracked in git. `_health-check.sh` reports warnings (not errors) for uncloned repos. Clone the repo and re-run `_setup.sh` to restore symlinks.

### When Brain isn't cloned

If Brain is not cloned on a machine, no project context is available. Clone Brain first, then code repos, then run `_setup.sh`.

### _Docs Symlink

`_Docs/` lives in Brain (`<Brain>/_Docs/<slug>/`) as a real directory. A symlink provides access from the code repo:

- **In code repo** (local-only, gitignored): `<repo>/project_files/brain/_Docs` -> `<Brain>/_Docs/<slug>/`

The code repo symlink is created by `_setup.sh` and gitignored. Each machine creates its own. Plans and docs are accessed via `project_files/brain/_Docs/Plans/`.

### Collab Repos — Dereference on Push

For collab repos (COLLAB=collab in `_projects.conf`), shared project context must be committed as real files so partners can pull them. The `/push-projectshared` skill handles this:

1. Temporarily replaces symlinks with real file copies from Brain
2. Shows diff and commits via `/commit`
3. Pushes to remote
4. Restores symlinks and sets `assume-unchanged` flags

Partners use `/pull-projectshared` to receive updates, which writes pulled content to Brain and restores symlinks.

Solo repos never need this — `project_files/brain/` is gitignored entirely.

### Claude Config Symlinks

`_setup.sh` creates these symlinks so Claude Code picks up Brain-managed config:

```
<Brain>/_ClaudeSettings/global/CLAUDE.md    -> ~/.claude/CLAUDE.md
<Brain>/_ClaudeSettings/global/settings.json -> ~/.claude/settings.json
<Brain>/_Skills/                      -> ~/.claude/skills/
```

Edits in either location take effect immediately (they're the same file via symlink).

---

## Git Architecture

Brain's git root is `<Brain>/`. Code repos under category directories (e.g., `Clients/`, `Personal/`, `<Business>/`) are separate git repositories, invisible to Brain's git.

**Obsidian Git** auto-syncs Brain (pull on startup, push on interval). No special config needed — git root = vault root.

### Conflict Prevention

For projects, `_ActiveSessions/<slug>/session.md` is a real file in Brain (code repos access it via symlink at `project_files/brain/session.md`). The session file uses a multi-person format where each collaborator writes their own `## <identity> | <date>` section. This prevents merge conflicts — different people edit different hunks.

- **save-session** replaces only the section matching the current `SYNC_IDENTITY`
- **start-session** reads all sections, shows partner's section for awareness
- No cross-project conflicts are possible — each project has its own session file
- Brain's own session (`brain/session.md`) remains a real file in `_ActiveSessions/`
- Parked projects live in `_ActiveSessions/_Parked/`. Parking/unparking is a `git mv`.

### session.md Format

Each project's `session.md` (canonical at `$BRAIN/_ActiveSessions/<slug>/session.md`, accessed via `project_files/brain/session.md` symlink) is the shared active session file. All collaborators write their own section. Each section is identified by the person's `SYNC_IDENTITY` from their `_sync.conf`.

Format:

```markdown
---
project: <ProjectName>
---

## <identity1> | <YYYY-MM-DD>

**Current:** <1-line summary>

### Handoff
- **Left off:** [file:function, state of code]
- **What got done:** [brief list]
- **Next:** [immediate next action]
- **Context:** [non-obvious info — gotchas, temp state, blockers]
- **Code state:** [verified git status]

## <identity2> | <YYYY-MM-DD>
[same structure]
```

Rules:
- `/save-session` replaces only YOUR section (matched by `SYNC_IDENTITY`)
- `/start-session` reads both sections, shows partner's for awareness
- On git merge: different sections merge cleanly (different hunks). Frontmatter is static so no conflict.
- First-time use: if no section exists for your identity, append a new one

---

## BrainShared — Shared Infrastructure

BrainShared is a separate GitHub repo that holds the shared core of the Brain system. Two partners each have their own private Brain vault, but they share skills, KnowledgeBase, templates, global memories, and conventions through BrainShared.

### Three-Repo Architecture

```
BrainShared (github.com/<org>/BrainShared)       <- shared infrastructure
Brain<Name> (github.com/<owner>/Brain<Name>)     <- each partner's private vault
```

Each partner's private Brain contains everything — shared and personal. BrainShared is the distribution channel for shared content only.

### What Is Shared vs Private

| Shared (in BrainShared) | Private (in each partner's Brain only) |
|--------------------------|----------------------------------------|
| `_Skills/` | `_Workbench/` |
| `_Templates/` | `_Profile/` |
| | `_Agents/` (each partner's personal agent personas) |
| `_KnowledgeBase/` | `_ActiveSessions/` |
| `_Memory/brain/` (global memories) | `_Memory/<project-slug>/` (per-project memories, canonical in Brain) |
| `WordOfWisdom.md` | `_projects.conf` |
| `_HowThisWorks.md` | `_DevLog/` |
| `key-to-dev.md` | `_Docs/` |
| `_setup.sh`, `_health-check.sh` | `_sync.conf` |
| `_ClaudeSettings/global/CLAUDE.md` | |
| `_ClaudeSettings/global/settings.json` | |
| `_sync.conf.template` | |

### Sync Config

Each partner has a `_sync.conf` file (not shared) created from the shared `_sync.conf.template`:

```bash
SHARED_BRAIN_REMOTE="git@github.com:<org>/BrainShared.git"
SHARED_BRAIN_BRANCH="main"
SHARED_ORG="<org>"
SYNC_IDENTITY="<name>"

# Remote commits — for comparing against BrainShared state
LAST_PUSH_COMMIT="<auto-updated by /push-brainshared>"
LAST_PUSH_DATE="<auto-updated by /push-brainshared>"
LAST_PULL_COMMIT="<auto-updated by /pull-brainshared>"
LAST_PULL_DATE="<auto-updated by /pull-brainshared>"

# Local commits — for git diff within the private Brain repo
LAST_LOCAL_PUSH_COMMIT="<auto-updated by /push-brainshared>"

# Per-project shared repos (for /push-projectshared, /pull-projectshared)
# Format: SLUG|REMOTE_URL|LAST_PUSH_COMMIT|LAST_PUSH_DATE|LAST_PULL_COMMIT|LAST_PULL_DATE
SHARED_PROJECTS=()
```

### How Sync Works

**Pushing updates (`/push-brainshared`):**
1. Detects local changes to shared content since last push
2. Clones BrainShared to temp dir, checks if partner pushed new changes
3. If partner has changes: AI merges — auto-merges non-conflicting changes, asks verification questions for real conflicts
4. Pushes merged result directly to main (no personal branches)
5. Updates `LAST_PUSH_COMMIT` and `LAST_PUSH_DATE`

**Pulling updates (`/pull-brainshared`):**
1. Checks for unpushed local changes — warns if found (default: abort)
2. Clones BrainShared to temp dir
3. Overrides local shared content with `rsync --delete` (skills, templates, KB)
4. `_Memory/brain/` uses `rsync` without `--delete` — additive only, never removes personal globals
5. Runs `_setup.sh` to propagate changes to `~/.claude/`
6. Updates `LAST_PULL_COMMIT` and `LAST_PULL_DATE`

**Golden rule: always `/push-brainshared` before `/pull-brainshared`.** Push saves your work to shared; pull overwrites your local shared content with the latest from main.

### Per-Project Sharing (via Code Repos)

Project context lives as real files in Brain. For collab repos, `/push-projectshared` dereferences symlinks into real files, commits, and pushes. `/pull-projectshared` pulls and writes content back to Brain.

- `CLAUDE.md`, `_Status.md`, `session.md` — dereferenced from Brain, committed as real files
- `memory/` — dereferenced from Brain, committed as real files
- `session.md` — multi-person format allows clean merges

### Partner Onboarding

When a new partner joins:

1. **Add collaborator** on the BrainShared GitHub repo (Settings → Collaborators)

2. **Partner clones BrainShared** as their Brain bootstrap:
   ```bash
   git clone git@github.com:<org>/BrainShared.git ~/Development/Brain<Name>
   cd ~/Development/Brain<Name>
   ```

3. **Run setup** (writes `BRAIN_ROOT` to shell config, creates `~/.claude/` symlinks):
   ```bash
   bash _setup.sh
   ```

4. **Create personal Brain structure** (directories not in BrainShared):
   ```bash
   mkdir -p _Workbench           # per-project scratch space (real directories)
   mkdir -p _Profile
   mkdir -p _ActiveSessions/_Parked
   mkdir -p _DevLog
   mkdir -p _Docs
   touch _projects.conf
   echo 'brain||Brain<Name>|' >> _projects.conf
   ```

5. **Configure sync**:
   ```bash
   cp _sync.conf.template _sync.conf
   # Edit _sync.conf: set SHARED_ORG, SYNC_IDENTITY
   ```

6. **Set up private Brain git**:
   ```bash
   git remote add brainshared git@github.com:<org>/BrainShared.git
   git remote set-url origin git@github.com:<owner>/Brain<Name>.git
   git push -u origin main
   ```

7. **Create `_Profile/` files** — collaborate with the AI to capture identity, skills, and preferences

8. **Verify**: `bash _health-check.sh`

After onboarding, the partner uses the same daily workflow: `/start-session` → work → `/commit` → `/save-session`. Shared improvements flow through `/push-brainshared` and `/pull-brainshared`. For ongoing vault validation, use `/brain-check` (wraps `_setup.sh` + `_health-check.sh`).

### Merge Conflict Prevention

Partners push directly to main on BrainShared. The AI merge algorithm in `/push-brainshared` handles conflicts:

1. Partner A pushes → AI fetches remote, detects no partner changes → pushes to main
2. Partner B pushes → AI fetches remote, detects Partner A's changes → auto-merges non-conflicting changes, asks about real conflicts → pushes merged result to main

If both partners push simultaneously, `git push` fails for the slower partner. The skill retries once with a fresh fetch and re-merge. The window for collision is small (seconds between fetch and push).

The golden rule: always push before you pull. This saves your work before overwriting with shared content.

### Pre-Push Checklist

Before running `/push-brainshared`, validate your local Brain so you're not pushing broken structure, stale content, or gaps to your partner. Run these in order:

| Step | Command | What It Validates | Fix |
|------|---------|-------------------|-----|
| 1 | `/brain-check` | Symlinks, memory seeding, core dirs/files, project registry, sync config, WordOfWisdom integrity | Runs `_setup.sh` (auto-fix) then `_health-check.sh` (validate) |
| 2 | `/folder-audit` | Structural correctness: orphaned dirs, broken symlinks, unregistered projects, naming violations, unindexed memory files (MEM-005) | Interactive repair |
| 2b | `/structure-audit` | Code repo internal layout: non-standard top-level dirs, platform targets, framework placement (Universal Project Structure) | Interactive repair |
| 3 | Content audit skills | Content quality: `/profile-audit`, `/memory-audit`, `/kb-audit`, `/devlog-audit`, `/status-audit`, `/vault-consistency-audit` — each audits one area independently | Report only (user fixes ad-hoc) |
| 4 | `/save-session` | Session context captured, memories synced | Writes session.md section, syncs global memories |
| 5 | `/push-brainshared` | Push validated content to BrainShared | AI-merge and push |

**When to run the full checklist:**
- Before your first push on a new machine
- After a string of heavy sessions (3+) without pushing
- After creating or onboarding new projects
- Weekly maintenance (run content audit skills as needed)

**Shortcut for daily pushes** (when you've been pushing regularly):
```
/brain-check → /save-session → /push-brainshared
```

Skip `/folder-audit` if the brain check passes clean and you haven't made structural changes. Content audit skills are optional — run them after heavy sessions or weekly.

**What each step catches:**

1. **`/brain-check`** — runs `_setup.sh` then `_health-check.sh` in sequence. Setup ensures `~/.claude/` symlinks point to the right Brain files, code repo `project_files/brain/` symlinks point into Brain, and skills are discoverable. Health check validates core directories, Brain canonical files are real (not symlinks), code repo symlinks point to Brain, memory symlink integrity, orphaned memory subdirectories, unregistered projects, WordOfWisdom drift, and sync config issues (missing fields, old format, staleness). Fast — under 10 seconds total.

2. **`/folder-audit`** — deep structural audit of `~/Development/`. Finds orphaned project directories not in `_projects.conf`, broken ActiveSessions/Workbench symlinks, missing `_Memory/<slug>/` directories, naming convention violations, and unindexed memory files (files in `_Memory/` dirs without corresponding MEMORY.md entries). Auto-repairs most issues interactively.

2b. **`/structure-audit`** — audits each code repo's internal directory layout against Universal Project Structure conventions. Flags non-standard top-level directories, platform targets that should be under `clients/`, and shared frameworks that belong in `core/`. Understands Xcode projects (parses `project.yml` for target-to-platform mapping). Interactive repair with per-item confirmation.

3. **Content audit skills** — six independent read-only audits, each covering one persistence tier. `/profile-audit` (Profile vs memories), `/memory-audit` (scope, dedup, quality, absorption), `/kb-audit` (KnowledgeBase freshness), `/devlog-audit` (DevLog quality), `/status-audit` (_Status.md and session freshness), `/vault-consistency-audit` (cross-project consistency, symlinks, doc drift). Run individually as needed — no orchestrator.

4. **`/save-session`** — captures current session context to `session.md` and syncs global memories from `~/.claude/projects/` back to `_Memory/brain/` in Brain git. Project memories are symlink-based and need no copy step.

---

## Memory Sync

All memory sync is symlink-based. `_setup.sh` creates symlinks from Claude's local memory dirs to the canonical `_Memory/<slug>/` directories in Brain.

### Project memories (symlink-based)

For every project except "brain", `_Memory/<slug>/` is a real directory in Brain containing the canonical memory files. Claude's local memory dir (`~/.claude/projects/<path-key>/memory/`) is a symlink pointing directly to `<Brain>/_Memory/<slug>/`. Code repos also have a symlink at `project_files/brain/memory` → `<Brain>/_Memory/<slug>/`. All paths resolve to the same Brain directory — no copy step is needed.

`_setup.sh` creates the Claude memory symlink. `/save-session` and `/start-session` do NOT copy project memories — the symlinks mean any write is immediately visible everywhere.

**Silent divergence detection:** If the Claude memory symlink breaks and Claude writes memories, a real directory gets created at the symlink location. `_health-check.sh` detects when `~/.claude/projects/<path-key>/memory/` is a real directory instead of a symlink and warns. Re-run `_setup.sh` to restore symlinks (manual merge may be needed for memories written while the symlink was broken).

### Global memories (symlink-based, same as projects)

`_Memory/brain/` contains real files tracked in Brain git, shared via BrainShared. `_setup.sh` creates a symlink from `~/.claude/projects/<path-key>/memory/` → `<Brain>/_Memory/brain/`, identical to how project memories work. No copy step is needed — writes go directly to the canonical location.

To permanently delete a global memory, remove from `<Brain>/_Memory/brain/`, update `MEMORY.md`, and commit Brain git. Since it's a symlink, there's no separate Claude copy to clean up.

---

## _Profile

`<Brain>/_Profile/` is the persistent user identity context for AI sessions. It's organized into subfiles so the AI can load only what's relevant to a given task.

| File | Contents | Load When |
|------|----------|-----------|
| `index.md` | Overview + pointers to subfiles | Any session needing user context (the entry point) |
| `identity.md` | Education, background, philosophy | Introductions, framing advice |
| `business.md` | Business state, clients, services | Client/pricing/deliverable decisions |
| `skills.md` | Languages, platforms, AI/ML expertise | Tech recommendations, architecture choices |
| `preferences.md` | Communication style, working patterns | Calibrating response style, new sessions |

**Sync:** Lives in Brain git. Reaches every machine automatically via vault sync — no symlinks or manual copy needed. The global `_ClaudeSettings/global/CLAUDE.md` references `_Profile/index.md` as the entry point.

---

## _Skills

`<Brain>/_Skills/` is the single source of truth for all custom Claude Code skills. On setup, `~/.claude/skills/` is symlinked to this directory, so any edits in Brain are immediately active.

Each skill is a directory containing a `SKILL.md` file that defines the skill's name, description, trigger conditions, and instructions. Skills are invoked via slash commands (e.g., `/start-session`, `/commit`).

### Core skill lifecycle

```
/start-session  ->  Load vault context, show where you left off
/commit         ->  Stage + commit (local). `/commit push` to also push to remote
/save-session   ->  Save handoff notes, update status, sync memories, commit Brain git
```

See `key-to-dev.md` for the full skill catalog and usage patterns.

---

## _Agents — Runtime Agent Brains

`<Brain>/_Agents/<name>/` holds persona, standing context, and private memory for AI agents that **run outside Claude Code** and consume the vault at runtime. This is parallel to — and distinct from — the project-slug system used by `_projects.conf`. Slugs map code repos to Brain artifacts via `project_files/brain/` symlinks; `_Agents/` map running processes to vault read/write scopes via a host-enforced whitelist.

### Structure

```
_Agents/
├── README.md                ← convention + current agent roster
└── <agent-name>/
    ├── persona.yaml         ← loaded at agent startup (identity, constraints)
    ├── standing-context.md  ← pointers the agent loads into its system prompt
    └── memory/              ← agent's private notes (writable)
        ├── MEMORY.md
        └── *.md
```

### Read/write scopes (host-enforced)

| Scope | Paths | Who writes |
|---|---|---|
| Read | `_Profile/`, `_ActiveSessions/`, `_DevLog/`, `_Memory/`, `_KnowledgeBase/`, `_Docs/`, `_Workbench/`, `_projects.conf`, `_Agents/<self>/` | — |
| Write | `_Docs/<slug>/`, `_Workbench/<slug>/`, `_Agents/<self>/memory/` | agent |
| Denied | `.git/`, `_ClaudeSettings/`, `_Skills/`, anything outside `BRAIN_ROOT` | — |

### Canonical persona via symlink

Like `_ClaudeSettings/<slug>/CLAUDE.md` and `_Memory/<slug>/`, an agent's persona is canonical in Brain. The agent's own codebase symlinks into Brain — e.g., `AgentDashboard/skills/oto/persona.yaml → $BRAIN_ROOT/_Agents/oto/persona.yaml`. Edit the persona in Brain; next agent restart picks it up.

### Current agents

- **oto** — chief of staff running in [AgentDashboard](_Docs/agentdashboard/). Routes iMessage conversations, orchestrates working groups, uses `brain_read` / `brain_write` tools to pull project context and persist artifacts.

---

## _KnowledgeBase

`<Brain>/_KnowledgeBase/` stores general technical knowledge that applies across projects and persists indefinitely. Not project-specific — those go in `_Status.md` Gotchas or project `CLAUDE.md`.

**Write to KB when you discover:**
- Platform/tool bugs or quirks (IDEs, language toolchains, OS behaviors)
- Framework API behaviors that apply to any project
- Cross-project gotchas

**File format:** Frontmatter with `tags: [reference, <domain>]`, topic heading, sections, Gotchas list. Each entry includes version context ("as of Tool v16", "library 0.15+") so staleness can be judged later.

---

## Universal Project Structure

Every code project follows the same layout, regardless of language or platform. Not every directory is needed from day one — create them as the project grows.

```
<Project>/
├── CLAUDE.md                    # Always at root
├── .gitignore
├── <manifest>                   # pyproject.toml, package.json, Cargo.toml, etc.
│
├── core/                        # Backend / shared logic (language-specific layout inside)
├── clients/                     # Platform-specific frontends (only when multi-platform)
│   ├── web/                     # React, Svelte, etc.
│   ├── macos/                   # SwiftUI
│   ├── ios/                     # SwiftUI
│   ├── desktop/                 # Tauri/Electron (wraps web for Linux/Windows)
│   └── shared/                  # Shared client code (Swift package, shared types, etc.)
├── test/                        # All tests (plural `tests/` also acceptable; follows language convention)
├── config/                      # App configuration that ships
│
└── project_files/               # Development support — never shipped
    ├── brain/                   # SYMLINKS to Brain (canonical files live in Brain)
    │   ├── CLAUDE.md            # Symlink -> <Brain>/_ClaudeSettings/<slug>/CLAUDE.md
    │   ├── _Status.md           # Symlink -> <Brain>/_ActiveSessions/<slug>/_Status.md
    │   ├── session.md           # Symlink -> <Brain>/_ActiveSessions/<slug>/session.md
    │   ├── memory               # Symlink -> <Brain>/_Memory/<slug>/
    │   ├── DevLog               # Symlink -> <Brain>/_DevLog/<slug>/
    │   ├── Workbench            # Symlink -> <Brain>/_Workbench/<slug>/
    │   └── _Docs                # Symlink -> <Brain>/_Docs/<slug>/ (gitignored)
    ├── data/                    # Runtime data, databases, generated files (gitignored)
    ├── assets/                  # Design files, source images (gitignored)
    └── tools/                   # Dev scripts, utilities (gitignored)
```

**Key rules:**
- Source code goes in `core/` and/or `clients/` — never loose at root (except manifest files and entrypoints)
- Solo repos: `.gitignore` includes `project_files/brain/` — all symlinks are gitignored
- Collab repos: `.gitignore` allows `project_files/brain/` for shared content (committed as real files via `/push-projectshared`)
- Plans and docs are accessed through `project_files/brain/_Docs/Plans/` — no separate `plans/` symlink at project root
- Single-platform projects may skip `clients/` entirely (e.g., a Python CLI tool uses just `core/`)
- Backend-only projects use `core/` without `clients/`

**What scales:**
- Adding a platform means adding one directory under `clients/`
- Shared client code extracts to `clients/shared/`
- The backend (`core/`) serves all clients via the same API
- `project_files/brain/` structure is identical across every project — same symlink layout pointing into Brain

---

## Adding a New Project

1. Add one line to `<Brain>/_projects.conf`: `<slug>|<Category>|<Category>/<Subcategory>/<Project>|<COLLAB>`
2. Create Brain directories with real files:
   ```bash
   mkdir -p <Brain>/_ActiveSessions/<slug>
   mkdir -p <Brain>/_ClaudeSettings/<slug>
   mkdir -p <Brain>/_Memory/<slug>
   mkdir -p <Brain>/_DevLog/<slug>
   mkdir -p <Brain>/_Workbench/<slug>
   mkdir -p <Brain>/_Docs/<slug>/{Plans,Reports}
   ```
3. Create `<Brain>/_ActiveSessions/<slug>/_Status.md` (include frontmatter: tags, created, category, client, status)
4. Create `<Brain>/_Memory/<slug>/MEMORY.md` (empty index)
5. Create `<Brain>/_ActiveSessions/<slug>/session.md` (with frontmatter: `project: <ProjectName>`)
6. Create `<Brain>/_ClaudeSettings/<slug>/CLAUDE.md` (project CLAUDE.md)
7. Clone code repo to `<Category>/<Subcategory>/<Project>/`
8. Update code repo `.gitignore`:
   ```
   .claude/
   project_files/brain/
   ```
9. Run `bash <Brain>/_setup.sh` to create symlinks (code repo project_files/brain/ -> Brain, Claude memory -> Brain)
10. Run `bash <Brain>/_health-check.sh` to verify

---

## Vault Maintenance

### Health Check

`bash <Brain>/_health-check.sh` verifies vault integrity:
- Core directories exist
- Brain canonical files are real files (not symlinks) in `_ActiveSessions/`, `_ClaudeSettings/`, `_Memory/`, `_DevLog/`, `_Workbench/`
- Code repo symlinks point to Brain
- Claude config symlinks point to the right targets
- Claude memory symlinks point to `<Brain>/_Memory/<slug>/`
- Every `_Memory/` subdirectory is registered in `_projects.conf`

Run after `_setup.sh` on new machines, or any time something feels wrong.

### Content Audit Skills

Six independent read-only audit skills, each covering one area of vault content quality. Run individually as needed — weekly or after heavy sessions. They complement `/save-session` (which captures in-session) by reviewing content quality across sessions.

| Skill | Area | What It Checks |
|-------|------|----------------|
| `/profile-audit` | Profile Freshness | `_Profile/` subfiles current against Claude Memory learnings |
| `/memory-audit` | Memory Evaluation | Bidirectional scope (promote/demote), dedup, quality, absorption into skills/KB/CLAUDE.md |
| `/kb-audit` | KB Freshness | Version context, staleness, format compliance |
| `/devlog-audit` | DevLog Maintenance | Oversized entries, empty sections, unpromoted decisions |
| `/status-audit` | Status & Session | Bloated Active Decisions, resolved Gotchas, stale handoffs |
| `/vault-consistency-audit` | Cross-Project Consistency | CLAUDE.md completeness, `_projects.conf` drift, `_HowThisWorks.md` doc drift, symlink integrity |

All are report-only — they present findings but do not modify files. Fix issues ad-hoc or with targeted commands.

---

## Naming Conventions

| Convention | Rule | Example |
|------------|------|---------|
| `_prefix` | All system/meta directories and files at vault root | `_Status.md`, `_Workbench/`, `_ClaudeSettings/`, `_DevLog/` |
| `PascalCase` | Project names, multi-word directory names | `MyProject`, `WebDashboard`, `ClaudeSettings` |
| `lowercase` | System/gitignored directories in code repos | `project_files/`, `brain/` |
| `kebab-case` | Slug directories and session files | `brain/session.md`, `myproject/session.md` |
| No spaces | All folder and file names | `_DevLog/`, `_ActiveSessions/` |
| `<Brain>/` | Generic Brain name in shared docs (prose, diagrams) — never hardcode `BrainOtolith` etc. | `<Brain>/_Skills/`, `<Brain>/_Workbench/` |
| `$BRAIN_ROOT` | Generic Brain path in runnable code/scripts in shared docs | `bash $BRAIN_ROOT/_setup.sh` |

---

## Runtime & Training Data

`project_files/data/` is gitignored and machine-local. Databases, raw images, datasets, and any generated files stay here. Trained model weights are fetched at runtime from cloud storage (S3, R2, HuggingFace Hub) — never committed to any repo. Design assets and source images go in `project_files/assets/`.

---

## Tags Taxonomy

- **Status:** `#active`, `#todo`, `#done`, `#blocked`, `#wip`
- **Platform:** `#windows`, `#linux`, `#macos`, `#ios`, `#android`, `#cross-platform`, `#desktop`
- **Domain:** `#security`, `#database`, `#ui`, `#auth`, `#networking`
- **Type:** `#brainstorm`, `#bug`, `#feature`, `#decision`, `#reference`, `#runbook`
- **Client:** `#client/personal`, `#client/<clientname>`
