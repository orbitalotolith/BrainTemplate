# Key to ~/Development/

Quick reference for daily workflows and skills. For vault structure and architecture, see `_HowThisWorks.md`.

---

## 1. Daily Workflows

### Development

Every session: `/start-session` → work → `/save-session` → `/commit`. The middle varies:

| Task            | Middle                                                  |
|-----------------|---------------------------------------------------------|
| Coding          | work → `/simplify`                                      |
| Planned feature | brainstorm → write plan → execute plan → `/simplify`    |
| Bug fix         | debug → fix → `/simplify`                               |
| Refactor        | `/refactor` → implement → `/simplify`                   |
| Code review     | review → address feedback → `/simplify`                 |
| TDD feature     | brainstorm → write plan → TDD (red → green)             |

### Shipping

| Type            | Workflow |
|-----------------|----------|
| Pre-release     | `/structure-audit` → `/code-audit` → `/security-audit` → `/test-create` → `/changelog` → `/ship-check` → `/commit push` |
| TestFlight      | `/testflight-check` → fix → `/commit push` |
| Client delivery | `/brand-identity-extractor` → `/code-audit` → `/security-audit` → `/ship-check` |

### Vault Maintenance

| Action              | Workflow |
|---------------------|----------|
| New project         | `/create-project` → `/brain-check` → work → `/save-session` |
| Structural audit    | `/brain-check` → `/folder-audit` → `/structure-audit` |
| Content audit       | `/profile-audit` → `/memory-audit` → `/kb-audit` → `/devlog-audit` → `/status-audit` → `/vault-consistency-audit` |
| Mid-session capture | `/capture` |
| Skill development   | brainstorm → write plan → `/writing-skills` → `/skill-audit` → `/save-session` → `/commit` |

**Apply audit findings:** after any `*-audit`, say "apply the `<name>-audit` findings" — Claude walks each one preview-then-confirm.

---

## 2. The Sync Cycle

The end-to-end loop for keeping all Brains coherent.

### Step 1 — Maintenance

Audit the vault before pushing.

| Tier | When                          | Skills |
|------|-------------------------------|--------|
| Lean | Daily / before most pushes    | `/brain-check` → `/folder-audit` |
| Deep | Before bigger pushes / monthly | `/profile-audit` → `/memory-audit` → `/kb-audit` → `/devlog-audit` → `/status-audit` → `/vault-consistency-audit` |

End with `/save-session` → `/commit`.

### Step 2 — `/push-brainshared`

AI-merge push of skills, KnowledgeBase, templates, and global memories to BrainShared.

### Step 3 — `/pull-brainshared` (other machines / partner)

Pull latest from BrainShared. Run on every other Brain you maintain.

### Step 4 — `/vault-migrate` + `/brain-check`

Settle any structural changes that arrived in the pull. `/vault-migrate` analyzes diffs and generates a migration plan; `/brain-check` fixes symlinks and validates integrity.

### Order tip — pushing structural changes

If your push includes structural moves (renames, new tier folders), run `/vault-migrate --local` before Step 2. That way the migration plan ships with the push, and other Brains apply a deterministic plan in Step 4 instead of reverse-engineering the move.

---

## 3. Per-Project Collab Sync

For collab repos — projects shared with a partner. Parallel mini-cycle, distinct from BrainShared.

### Push

`/save-session` → `/commit` (only if you have uncommitted code to include) → `/push-projectshared`

`/push-projectshared` owns its own commit + push: it commits the brain context files separately and runs the actual git push with `ALLOW_COLLAB_PUSH=1`. It will warn but not auto-commit any uncommitted code changes — run `/commit` (no push) first if you want them included.

### Pull

`/pull-projectshared` → `/brain-check` → `/start-session`

### Why these skills exist

Collab repos use `project_files/brain/` symlinks pointing into your private Brain. Bare `git push` would dereference and leak private content; bare `git pull` would overwrite the symlinks with real files. The skills handle the dereference/restore dance.

A pre-push hook blocks bare push unless `ALLOW_COLLAB_PUSH=1` (set by `/push-projectshared`); a post-merge hook warns when a pull has overwritten symlinks.

---

## 4. Skills Reference

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
| `/profile-audit` | Audit `_Profile/` subfiles against user-type memories |
| `/memory-audit` | Audit memory scope, dedup, quality, and absorption |
| `/kb-audit` | Audit KnowledgeBase entries for freshness and format |
| `/devlog-audit` | Audit DevLog entries for quality and unpromoted knowledge |
| `/status-audit` | Audit `_Status.md` and session files for freshness |
| `/vault-consistency-audit` | Audit cross-project consistency, symlinks, doc drift |
| `/folder-audit` | Structural audit of `~/Development/` (Brain integration, symlinks, registry) |
| `/structure-audit` | Audit code repo internal layout against Universal Project Structure |
| `/vault-migrate` | Analyze structural differences and generate migration plan (post-pull, pre-push, or local) |
| `/skill-audit` | Audit skills for conformance, health, and fitness |
| `/pull-skills` | Pull latest skills from BrainShared |

---

## 5. Identity & Architecture

### Brain architecture

- Vault structure, sync model, knowledge hierarchy → `_HowThisWorks.md`
- User profile (identity, business, skills, preferences) → `_Profile/`
- Project registry → `_projects.conf`

### New Machine Setup

1. Create the folder: `mkdir -p ~/Development/Brain<Name>`
2. Open Claude Code in that folder
3. Run `/setup-new-brain` — when prompted, paste the BrainTemplate URL: `git@github.com:<org>/BrainTemplate.git`

The skill clones BrainTemplate, runs `_setup.sh`, and walks identity, persona, git remotes, and optional BrainShared collab.

#### Windows prerequisites

- Run shell scripts from **Git Bash** (not PowerShell or CMD).
- **Developer Mode ON** (Settings → Privacy & security → For developers) — symlinks fall back to copies otherwise.
- `git config --global core.symlinks true`
- SSH key registered with GitHub.
