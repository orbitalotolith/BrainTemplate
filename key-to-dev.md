# Key to ~/Development/

Quick reference for workflows and skills. For vault structure and architecture, see `_HowThisWorks.md`.

---

## Workflows

### Development

**Coding session:** `/start-session` → work → `/simplify` → `/save-session` → `/commit`

**Planned feature:** `/start-session` → brainstorm → write plan → execute plan → `/simplify` → `/save-session` → `/commit`

**Bug fix:** `/start-session` → debug → fix → `/simplify` → `/save-session` → `/commit`

**Refactor:** `/start-session` → `/refactor` → implement recommendations → `/simplify` → `/save-session` → `/commit`

**Code review:** `/start-session` → review → address feedback → `/simplify` → `/save-session` → `/commit`

**TDD feature:** `/start-session` → brainstorm → write plan → TDD (write tests → implement → green) → `/save-session` → `/commit`

### Shipping

**Pre-release:** `/structure-audit` → `/code-audit` → `/security-audit` → `/test-create` → `/changelog` → `/ship-check` → `/commit push`

**TestFlight submission:** `/testflight-check` → fix issues → `/commit push`

**Client delivery:** `/brand-identity-extractor` → `/code-audit` → `/security-audit` → `/ship-check`

### Vault Maintenance

**New project:** `/create-project` → `/brain-check` → work → `/save-session`

**Structural audit:** `/brain-check` → `/folder-audit` → `/structure-audit`

**Content audit:** `/profile-audit` → `/memory-audit` → `/kb-audit` → `/devlog-audit` → `/status-audit` → `/vault-consistency-audit`

**Apply an audit's findings:** After any `*-audit` skill produces findings, say `apply the <name>-audit findings` — Claude walks through each interactively with preview-then-confirm. For `/status-audit` specifically, cleanup routes entries across the project knowledge hierarchy: short conventions to `_ClaudeSettings/<slug>/CLAUDE.md`, architectural rationale to `_DevLog/<slug>/architecture.md` (not auto-loaded), resolved Gotchas to `_DevLog/<slug>/archive.md`, cross-project quirks to `_KnowledgeBase/`. See `_HowThisWorks.md` → "Project Knowledge Hierarchy" for the full picture.

**Skill development:** brainstorm → write plan → `/writing-skills` workflow → `/skill-audit` → `/save-session` → `/commit`

### Sync

**Push to BrainShared:** `/brain-check` → `/folder-audit` → `/save-session` → `/commit push` → `/push-brainshared`

**Pull from BrainShared:** `/push-brainshared` → `/pull-brainshared` → `/brain-check` → `/vault-migrate` → review plan → execute plan

**Push after local structural changes:** `/vault-migrate --local` → review plan → execute plan → `/brain-check` → `/save-session` → `/commit push` → `/push-brainshared`

**Partner catching up after structural changes:** `/pull-skills` → `/push-brainshared` → `/pull-brainshared` → `/vault-migrate` → `/brain-check`

**Collab project push:** `/save-session` → `/push-projectshared` → `/commit push`

**Collab project pull:** `/pull-projectshared` → `/brain-check` → `/start-session`

### Setup

**New Brain (machine or partner):** clone BrainTemplate → `_setup.sh` → `/setup-new-brain`

---

## Skills

### Daily

| Command | What It Does |
|---------|-------------|
| `/start-session` | Load context from vault + project, show where you left off |
| `/commit` | Stage + commit (local). `/commit push` to also push |
| `/save-session` | Save handoff notes, update status, sync vault |
| `/save-lightweight` | Quick state checkpoint — session handoff, git state, timestamp only |
| `/vault-search` | Search DevLog and KnowledgeBase for past decisions |

### Partner Sync

| Command | What It Does |
|---------|-------------|
| `/push-brainshared` | AI-merge push to BrainShared |
| `/pull-brainshared` | Pull latest from BrainShared |
| `/push-projectshared` | Dereference symlinks, commit shared project context, push (collab repos) |
| `/pull-projectshared` | Pull, write to Brain, restore symlinks (collab repos) |

### Quality & Maintenance

| Command                     | What It Does                                         |
| --------------------------- | ---------------------------------------------------- |
| `/simplify`                 | Quick review of your current diff — reuse, quality, efficiency. Run after writing code |
| `/refactor`                 | Analyze code for refactoring opportunities — security-first, advisory by default |
| `/code-audit`               | Full codebase audit — types, duplicates, naming, lint, dead code. Run before shipping |
| `/security-audit`           | Security, dependency, and deployment readiness audit |
| `/test-create`              | Generate tests following project conventions         |
| `/changelog`                | Generate changelog from git history                  |
| `/ship-check`               | Audit project for client delivery readiness          |
| `/testflight-check`         | Audit iOS/macOS app for TestFlight readiness         |
| `/brand-identity-extractor` | Extract brand guidelines from client assets          |

### Vault & Brain

| Command | What It Does |
|---------|-------------|
| `/create-project` | Onboard a project into the Brain vault |
| `/brain-check` | Fix symlinks + validate vault integrity |
| `/profile-audit` | Audit _Profile/ subfiles against user-type memories |
| `/memory-audit` | Audit memory scope, dedup, quality, and absorption |
| `/kb-audit` | Audit KnowledgeBase entries for freshness and format |
| `/devlog-audit` | Audit DevLog entries for quality and unpromoted knowledge |
| `/status-audit` | Audit _Status.md and session files for freshness |
| `/vault-consistency-audit` | Audit cross-project consistency, symlinks, doc drift |
| `/folder-audit` | Structural audit of ~/Development/ (Brain integration, symlinks, registry) |
| `/structure-audit` | Audit code repo internal layout against Universal Project Structure |
| `/vault-migrate` | Analyze structural differences and generate migration plan (post-pull, pre-push, or local) |
| `/skill-audit` | Audit skills for conformance, health, and fitness |
| `/pull-skills` | Pull latest skills from BrainShared |

### Planning (Superpowers plugin)

| Need | What to Ask |
|------|-------------|
| Explore options before building | "Let's brainstorm" |
| Detailed implementation plan | "Write a plan" |
| Execute a written plan | "Execute the plan" |
| Test-driven development | "Use TDD" |
| Debug a problem | "Debug this" |
| Code review | "Review this" |

---

## Partner Sync

BrainShared distributes skills, KnowledgeBase, templates, and global memories between partners. Each partner has their own private Brain. For collab repos, `/push-projectshared` and `/pull-projectshared` handle project-specific context sync.

**To sync:** `/push-brainshared` before `/pull-brainshared`. Push saves your work; pull overwrites shared content with latest. For collab repos, use `/push-projectshared` and `/pull-projectshared`.

**New partner setup:** Tell Claude to "set up Brain from BrainShared" — it will clone the repo, run setup, create personal directories, configure sync, and verify.

---

## New Machine Setup

Clone BrainTemplate (`<org>/BrainTemplate`), run `_setup.sh`, open Claude Code, run `/setup-new-brain`. The skill walks identity, persona, git remotes, and optional BrainShared collab. Works on macOS, Linux, and Windows.

```bash
git clone git@github.com:<org>/BrainTemplate.git ~/Development/Brain<Name>
cd ~/Development/Brain<Name>
bash _setup.sh
# then in Claude Code: /setup-new-brain
```

Then open Obsidian, point it at the Brain directory, and enable plugins: Dataview, Templater, Obsidian Git.

### Windows prerequisites

`_setup.sh` and `_health-check.sh` are bash — on Windows, run them from **Git Bash** (ships with Git for Windows), not PowerShell or CMD.

1. Git for Windows installed (provides Git Bash).
2. **Developer Mode ON** (Settings → Privacy & security → For developers). Without this, symlinks silently fall back to copies and the vault breaks.
3. `git config --global core.symlinks true` — so git respects symlinks in pulls/clones.
4. SSH key registered with GitHub (for cloning the private Brain repo).

Verify: open Claude Code, start a session in Brain, confirm skills load. If symlinks appear as copies in `~/.claude/`, Developer Mode isn't on.

Known gotcha: `_health-check.sh` uses `date -j -f` (macOS-only) in one spot — non-blocking, but expect one warning on Windows/Linux until fixed.
