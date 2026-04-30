---
name: setup-new-brain
description: Use after cloning BrainTemplate on a new machine (or for a new partner identity) to wire identity, persona, git remotes, and optional BrainShared collab in one session. Works on macOS, Linux, and Windows (Git Bash).
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Setup New Brain

Bootstraps a fresh BrainTemplate clone into a fully-configured private Brain. Idempotent — safe to re-run after a partial setup.

## When to use

- Just cloned `BrainTemplate` on a new machine.
- Adding a new partner identity (e.g. a third partner joining an existing two-machine partnership).

If you already have a working Brain on this machine and want to pull updates, use `/pull-brainshared` instead.

## Process

### 0. Read Gotchas

Read `gotchas.md` in this skill's directory (if it exists) before proceeding. Known failure modes inform execution.

---

### 0.5. Bootstrap (if empty directory)

If the current working directory is **not** yet a Brain (no `_HowThisWorks.md`, no `.git/`), enter bootstrap mode. Otherwise skip to Step 1.

Use the **Bash** tool to detect bootstrap state:

```bash
if [ ! -f "_HowThisWorks.md" ] && [ ! -d ".git" ]; then
  BOOTSTRAP=1
  echo "[bootstrap] Empty directory detected — will clone BrainTemplate."
else
  BOOTSTRAP=0
fi
```

If `BOOTSTRAP=1`, proceed through 0.5a–0.5c. Otherwise jump to Step 1.

#### 0.5a — Resolve the BrainTemplate URL

If the user's invocation already supplied a URL (e.g. "Set up this new Brain from the BrainTemplate repo: `git@github.com:foo/BrainTemplate.git`"), use that URL directly.

Otherwise ask the user in plain conversation: "What's the BrainTemplate repo URL?" Expected format is `git@github.com:<org>/BrainTemplate.git` (SSH) or `https://github.com/<org>/BrainTemplate.git` (HTTPS). Store their answer as `BRAIN_TEMPLATE_URL`.

#### 0.5b — Clone into current directory

Use the **Bash** tool. `git clone <url> .` requires an empty directory — including no hidden files. Pre-clean the macOS `.DS_Store` (universally safe in an empty Brain dir), then abort if anything else remains:

```bash
rm -f .DS_Store
remaining="$(ls -A)"
if [ -n "$remaining" ]; then
  echo "ERROR: Directory not empty (contains: $(echo "$remaining" | tr '\n' ' '))."
  echo "       Bootstrap requires an empty directory. Remove these files and re-run the skill."
  exit 1
fi
git clone "$BRAIN_TEMPLATE_URL" . || { echo "ERROR: git clone failed."; exit 1; }
```

#### 0.5c — Run `_setup.sh`

```bash
bash _setup.sh || { echo "ERROR: _setup.sh failed — fix output above before re-running the skill."; exit 1; }
```

After 0.5c, fall through to Step 1. Pre-flight will now succeed because `_HowThisWorks.md` and `_projects.conf` exist.

---

### 1. Pre-flight

Use the **Bash** tool to verify the environment:

```bash
# Must run from a Brain repo root
[ -f "_HowThisWorks.md" ] && [ -f "_projects.conf" ] || {
  echo "ERROR: Run this skill from the root of a Brain repo (cloned BrainTemplate)."
  exit 1
}

# Detect platform
PLATFORM="$(uname -s)"
case "$PLATFORM" in
  Darwin)             OS="macos" ;;
  Linux)              OS="linux" ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
  *)                  OS="unknown" ;;
esac
echo "Platform: $OS"

# Windows-only: confirm symlinks are enabled
if [ "$OS" = "windows" ]; then
  if [ "$(git config --get core.symlinks 2>/dev/null)" != "true" ]; then
    echo "ERROR: Windows requires 'git config --global core.symlinks true' AND Developer Mode ON."
    echo "       See key-to-dev.md 'Windows' section for full prereqs."
    exit 1
  fi
fi

# Detect prior progress (informational — every later step is idempotent)
[ -f "_sync.conf" ]                                && echo "[detected] _sync.conf exists"
ls -d _Agents/*/ 2>/dev/null | grep -v "_template" && echo "[detected] persona already exists"
[ -L "$HOME/.claude/skills" ]                      && echo "[detected] _setup.sh has run"
```

If pre-flight fails, stop and surface the error to the user.

---

### 2. Step A — Identity

Use **AskUserQuestion** to collect identity values in one call. Phrase the questions plainly:

1. **Identity slug** — short lowercase name (e.g. `alice`, `bob`). Used for `SYNC_IDENTITY`, `_Agents/<slug>/` directory, and commit attribution. Free text via "Other".
2. **Display name** — title-case version (e.g. `Alice`). Used in persona greeting and commit messages.
3. **BrainShared owner** — GitHub org/user that hosts BrainShared. Default to whatever the existing `_sync.conf.template` shows; offer the default + "Other".
4. **Brain repo owner** — GitHub user that will host THIS Brain. Options: "Same as BrainShared owner" / "Different — enter username via Other".

After collecting answers, derive:
- `BRAIN_REPO_NAME = "Brain<DisplayName>"` (e.g. `BrainAlice`)
- `BRAIN_REMOTE = "git@github.com:<brain-repo-owner>/$BRAIN_REPO_NAME.git"`
- `SHARED_REMOTE = "git@github.com:<brainshared-owner>/BrainShared.git"`

Confirm derived values back to the user in plain text before proceeding.

---

### 3. Step B — Write `_sync.conf`

Skip if `_sync.conf` already exists.

Use the **Bash** tool to copy and substitute:

```bash
cp _sync.conf.template _sync.conf

# Substitute placeholder values (sed -i differs Mac vs Linux; use a temp-file pattern)
sed_inplace() {
  if [ "$OS" = "macos" ]; then sed -i '' "$@"; else sed -i "$@"; fi
}
sed_inplace "s|YOUR_ORG|<brainshared-owner>|g"   _sync.conf
sed_inplace "s|YOUR_NAME|<identity-slug>|g"      _sync.conf
```

Verify by reading `_sync.conf` back and confirming the three placeholder strings are gone.

---

### 4. Step C — Run `_setup.sh`

Use the **Bash** tool:

```bash
bash _setup.sh
```

This creates `_Workbench/`, `_Profile/`, `_Agents/`, `_ActiveSessions/_Parked/`, `_AgentTasks/`, the `~/.claude/` symlinks, and regenerates `.claude/commands/`. Already idempotent — safe if it ran before.

---

### 5. Step D — Persona scaffold

Use **AskUserQuestion** to pick the persona source (single question, four options):

1. **Default scaffold** — copy `_Agents/_template/` and substitute placeholders. Recommended for a fresh new identity.
2. **Copy from local Brain** — provide a path to an existing `_Agents/<src>/` on this machine. The skill copies it and renames.
3. **Copy from another machine via scp** — provide an SSH host (e.g. `<user>@my-mac.local`) and source identity. The skill validates SSH access then runs `scp -r`.
4. **Skip** — you'll create `_Agents/<slug>/persona.yaml` manually later.

For each option:

**Option 1 (default):**
```bash
cp -r _Agents/_template _Agents/<identity-slug>
sed_inplace "s|__IDENTITY__|<identity-slug>|g"     _Agents/<identity-slug>/persona.yaml
sed_inplace "s|__DISPLAY_NAME__|<display-name>|g"  _Agents/<identity-slug>/persona.yaml
sed_inplace "s|__IDENTITY__|<identity-slug>|g"     _Agents/<identity-slug>/standing-context.md
sed_inplace "s|__DISPLAY_NAME__|<display-name>|g"  _Agents/<identity-slug>/standing-context.md
```

**Option 2 (local copy):**
```bash
SRC_PATH="<user-supplied path>"
[ -d "$SRC_PATH" ] || { echo "ERROR: $SRC_PATH not found"; exit 1; }
cp -r "$SRC_PATH" _Agents/<identity-slug>
# Rename name: and display_name: in persona.yaml; rename agent: in standing-context.md
sed_inplace "s|^name: .*|name: <identity-slug>|"             _Agents/<identity-slug>/persona.yaml
sed_inplace "s|^display_name: .*|display_name: <display-name>|" _Agents/<identity-slug>/persona.yaml
sed_inplace "s|^agent: .*|agent: <identity-slug>|"           _Agents/<identity-slug>/standing-context.md
echo "Copied. Review _Agents/<identity-slug>/ and edit any other identity-specific text."
```

**Option 3 (scp from remote):**
```bash
SSH_HOST="<user-supplied>"   # e.g. <user>@my-mac.local
SRC_IDENTITY="<user-supplied>"  # e.g. your-agent-name
SRC_PATH="<user-supplied path on remote, default ~/Development/Brain<SrcName>/_Agents/$SRC_IDENTITY>"

# Validate SSH first; if it fails, fall back to option 1 with a notice
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_HOST" true 2>/dev/null; then
  echo "ERROR: SSH to $SSH_HOST failed (no key, host unreachable, or interactive prompt)."
  echo "       Fall back to option 1 (default scaffold) or set up SSH first."
  exit 1
fi

scp -r "$SSH_HOST:$SRC_PATH" _Agents/<identity-slug>
sed_inplace "s|^name: .*|name: <identity-slug>|"             _Agents/<identity-slug>/persona.yaml
sed_inplace "s|^display_name: .*|display_name: <display-name>|" _Agents/<identity-slug>/persona.yaml
sed_inplace "s|^agent: .*|agent: <identity-slug>|"           _Agents/<identity-slug>/standing-context.md
echo "Copied from $SSH_HOST. Review _Agents/<identity-slug>/ for any other identity-specific text."
```

**Option 4 (skip):** print a one-liner reminder and continue.

After persona is in place, re-run `bash _setup.sh` if it had not yet created `_Memory/<identity-slug>/` (the script creates per-identity memory dirs from `_Agents/` listing).

---

### 6. Step E — `_projects.conf`

Mandatory — no skip option. Use the **Edit** tool to ensure `_projects.conf` contains the brain row:

```
brain||<BRAIN_REPO_NAME>|
```

If the file already has a `brain|` row, leave it. Otherwise append.

Then ask the user (single AskUserQuestion): "Register any code repos now?" — Yes / Not yet.

If yes: tell them to invoke `/create-project` once for each repo (the skill already handles project scaffolding end-to-end). Don't reimplement here.

---

### 7. Step F — Git remotes

Use **AskUserQuestion**: "Configure git remotes now?" — Yes / Later.

If Later: print the manual commands and continue.

If Yes:

```bash
# origin → user's private Brain repo (must already exist as empty repo on GitHub)
git remote set-url origin "$BRAIN_REMOTE" 2>/dev/null || git remote add origin "$BRAIN_REMOTE"

# brainshared → reference remote for sync skills
git remote get-url brainshared >/dev/null 2>&1 || git remote add brainshared "$SHARED_REMOTE"

# Initial push
git add -A
git commit -m "chore: initial Brain setup ($identity-slug)" || true   # may be empty if no changes
git push -u origin main
```

Skip silently if remotes already point at the right URLs.

---

### 8. Step G — Optional BrainShared collab

Use **AskUserQuestion**: "Pull latest skills + KnowledgeBase from BrainShared?" — Yes / Not now.

Remind the user: BrainShared access requires being added as a collaborator on the GitHub repo. If they're not already added, ask them to confirm before proceeding.

If yes: invoke the existing `/pull-brainshared` skill (do NOT reimplement). It handles the clone, merge, and `_setup.sh` re-run.

---

### 9. Step H — Verification

Run these in order:

```bash
# 1. Health check (allow non-blocking date warning on Win/Linux)
bash _health-check.sh
HEALTH_EXIT=$?
[ $HEALTH_EXIT -eq 0 ] || echo "WARN: _health-check.sh exited $HEALTH_EXIT — review output above."

# 2. Persona greet (manual confirmation by Claude reading _Agents/<id>/persona.yaml)
echo "About to greet under new identity. Confirm Claude loads _Agents/<identity-slug>/persona.yaml."

# 3. Profile presence
if grep -q "TODO: fill in your" _Profile/identity.md 2>/dev/null; then
  echo "[note] _Profile/identity.md is still a TODO stub — populate via conversation later."
fi

# 4. Sync dry-run
git remote -v
git ls-remote origin HEAD >/dev/null 2>&1 && echo "origin auth OK" || echo "WARN: origin auth failed"

# 5. Symlink spot-check (Windows-critical)
if [ "$OS" = "windows" ]; then
  SKILLS_TYPE="$(ls -ld "$HOME/.claude/skills" 2>/dev/null | cut -c1)"
  if [ "$SKILLS_TYPE" = "l" ]; then
    echo "[ok] ~/.claude/skills is a symlink"
  else
    echo "ERROR: ~/.claude/skills is NOT a symlink (Developer Mode is likely off)."
    echo "       See key-to-dev.md 'Windows' section."
  fi
fi
```

Then read `_Agents/<identity-slug>/persona.yaml` and acknowledge the new identity in conversation. This verifies the persona file is parseable.

After the skill exits, the user should manually verify Claude Code itself loads the symlinked config:
- Open a new Claude Code session in this directory.
- Run `/start-session` and confirm it loads cleanly.

---

### 10. Step I — Final summary

Print a concise summary listing:
- Identity slug + display name
- Brain repo URL (origin) + push status
- Persona source (default / local copy / scp)
- BrainShared status (pulled / not pulled)
- Next steps:
  - `/start-session` to begin daily work
  - `/create-project <slug>` to register code repos
  - `/pull-brainshared` to sync shared content later

---

## Rules

- **Idempotent.** Every step checks "already done?" first and short-circuits. Re-running after a partial setup is safe.
- **Never overwrite** an existing `_sync.conf`, `_Agents/<slug>/`, or git remote. Confirm before destructive moves.
- **No commits to BrainShared** — this skill only sets up a private Brain. Sharing happens via `/push-brainshared` and `/push-projectshared` (separate skills).
- **No persona content in BrainShared.** `_Agents/` is private per-Brain by architecture. The scp option (Step D) is point-to-point.
- **Stop on Windows symlink failure.** Pre-flight aborts if `core.symlinks` is unset; post-setup verification flags if `~/.claude/skills` is a real directory instead of a symlink.

## Output

A configured private Brain ready for daily use:
- `_sync.conf` populated with the user's identity and BrainShared remote.
- `_Agents/<identity-slug>/` with persona scaffolded (default, copied, or skipped).
- `_projects.conf` with the `brain` row.
- Git remotes wired (`origin` to private Brain repo; `brainshared` reference).
- Optional: BrainShared content pulled.
- Verification report.
