#!/bin/bash
# Run after cloning Brain. Clone code repos first, then run this.
# Mac and Linux only.
set -e

BRAIN="${BRAIN_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
DEV="$HOME/Development"
CONF="$BRAIN/_projects.conf"

if [ ! -f "$CONF" ]; then
  echo "FATAL: $CONF not found. Cannot proceed."
  exit 1
fi

# --- Write BRAIN_ROOT to shell config (idempotent) ---

write_brain_root() {
  local shell_rc=""
  if [ -f "$HOME/.zshrc" ]; then
    shell_rc="$HOME/.zshrc"
  elif [ -f "$HOME/.bashrc" ]; then
    shell_rc="$HOME/.bashrc"
  elif [ -f "$HOME/.bash_profile" ]; then
    shell_rc="$HOME/.bash_profile"
  fi
  if [ -n "$shell_rc" ]; then
    if ! grep -q "BRAIN_ROOT" "$shell_rc"; then
      echo "" >> "$shell_rc"
      echo "# Brain vault root (set by _setup.sh)" >> "$shell_rc"
      echo "export BRAIN_ROOT=\"$BRAIN\"" >> "$shell_rc"
      echo "  ✓ BRAIN_ROOT=$BRAIN written to $shell_rc"
    else
      echo "  ⊘ BRAIN_ROOT already in $shell_rc (skipped)"
    fi
  else
    echo "  ⚠ No shell rc found — set BRAIN_ROOT manually: export BRAIN_ROOT=\"$BRAIN\""
  fi
}

echo "-- Shell environment --"
write_brain_root
echo ""

# --- Symlink helper ---

# Create a symlink $dest → $src, replacing any existing real directory at $dest.
# ln -sfn on an existing real directory creates the link INSIDE it rather than
# replacing it, so we must rm -rf first. Directory targets only.
safe_dir_symlink() {
  local src="$1"
  local dest="$2"
  if [ -d "$dest" ] && [ ! -L "$dest" ]; then
    rm -rf "$dest"
  fi
  ln -sfn "$src" "$dest"
}

# --- Read project registry ---

# Parse _projects.conf: SLUG|CATEGORY|CODE_PATH|COLLAB
SLUGS=()
CATEGORIES=()
CODE_PATHS=()
COLLABS=()
while IFS='|' read -r slug category code collab; do
  [[ "$slug" =~ ^#.*$ || -z "$slug" ]] && continue
  SLUGS+=("$slug")
  CATEGORIES+=("$category")
  CODE_PATHS+=("$code")
  COLLABS+=("$collab")
done < "$CONF"

# --- Create vault directories ---

echo "-- Vault directories --"
mkdir -p "$BRAIN/_ActiveSessions/_Parked"
mkdir -p "$BRAIN/_Docs"
mkdir -p "$BRAIN/_Profile"
mkdir -p "$BRAIN/_Workbench"
mkdir -p "$BRAIN/_Agents"
for i in "${!SLUGS[@]}"; do
  slug="${SLUGS[$i]}"
  # Don't create _ActiveSessions/<slug>/ if project is parked
  if [ ! -d "$BRAIN/_ActiveSessions/_Parked/$slug" ]; then
    mkdir -p "$BRAIN/_ActiveSessions/$slug"
  fi
  mkdir -p "$BRAIN/_ClaudeSettings/$slug"
  mkdir -p "$BRAIN/_DevLog/$slug"
  mkdir -p "$BRAIN/_Docs/$slug/Plans" "$BRAIN/_Docs/$slug/Reports"
  mkdir -p "$BRAIN/_Memory/$slug"
  if [ ! -f "$BRAIN/_Memory/$slug/MEMORY.md" ]; then
    echo "# Memory Index" > "$BRAIN/_Memory/$slug/MEMORY.md"
  fi
  mkdir -p "$BRAIN/_Workbench/$slug"
done
echo "  ✓ All per-project directories created"

# --- Configure Claude Code ---

setup_claude() {
  local CLAUDE_DIR="$HOME/.claude"
  local CONFIG="$BRAIN/_ClaudeSettings"

  mkdir -p "$CLAUDE_DIR"

  # Clean up stale ephemeral files (session artifacts, debug logs, old plans)
  for stale_dir in session-env debug tasks paste-cache file-history shell-snapshots; do
    if [ -d "$CLAUDE_DIR/$stale_dir" ]; then
      rm -rf "${CLAUDE_DIR:?}/$stale_dir/"*
    fi
  done
  rm -f "$CLAUDE_DIR/unsaved-sessions.log"
  echo "  ✓ Cleaned stale ephemeral files"

  # Clean up old auto-generated plans from default location
  local old_plans="$CLAUDE_DIR/plans"
  if [ -d "$old_plans" ] && [ ! -L "$old_plans" ]; then
    local old_count
    old_count=$(find "$old_plans" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
    if [ "$old_count" -gt 0 ]; then
      rm -f "$old_plans"/*.md
      echo "  ✓ Cleaned $old_count old plan file(s) from ~/.claude/plans/"
    fi
  fi

  # Global Claude instructions (symlink — changes tracked in Brain git)
  ln -sfn "$CONFIG/global/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  echo "  ✓ ~/.claude/CLAUDE.md → $CONFIG/global/CLAUDE.md"

  # Settings (symlink — plugin/hook changes tracked in Brain git)
  ln -sfn "$CONFIG/global/settings.json" "$CLAUDE_DIR/settings.json"
  echo "  ✓ ~/.claude/settings.json → $CONFIG/global/settings.json"

  # Hooks: ensure all _Hooks/*.sh scripts are executable. Hook commands are
  # referenced by absolute path from settings.json — no symlink needed.
  if [ -d "$BRAIN/_Hooks" ]; then
    local hook_count=0
    for hook in "$BRAIN/_Hooks"/*.sh; do
      [ -f "$hook" ] || continue
      chmod +x "$hook"
      hook_count=$((hook_count + 1))
    done
    if [ "$hook_count" -gt 0 ]; then
      echo "  ✓ _Hooks: $hook_count script(s) marked executable"
    fi

    # Sanity check: settings.json hook commands should reference paths under
    # this Brain. Warn (not fail) if any reference a different Brain location —
    # cross-machine setup may need a per-machine override in settings.local.json.
    if grep -q '"hooks"' "$CONFIG/global/settings.json" 2>/dev/null; then
      local bad_paths
      bad_paths=$(grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*_Hooks/[^"]*"' "$CONFIG/global/settings.json" \
                  | grep -v "$BRAIN" || true)
      if [ -n "$bad_paths" ]; then
        echo "  ⚠ settings.json hook command references a Brain path other than $BRAIN:"
        echo "$bad_paths" | sed 's/^/      /'
        echo "    If this is the wrong machine, add a per-machine override in ~/.claude/settings.local.json."
      fi
    fi
  fi

  # Skills (symlink — Brain/_Skills/ is the single source of truth)
  if [ -d "$CLAUDE_DIR/skills" ] && [ ! -L "$CLAUDE_DIR/skills" ]; then
    rm -rf "$CLAUDE_DIR/skills"
  fi
  ln -sfn "$BRAIN/_Skills" "$CLAUDE_DIR/skills"
  echo "  ✓ ~/.claude/skills → $BRAIN/_Skills"

  # Rebuild .claude/commands/ from _Skills/ (auto-generates, removes stale)
  local CMD_DIR="$BRAIN/.claude/commands"
  mkdir -p "$CMD_DIR"
  find "$CMD_DIR" -maxdepth 1 -type l -delete 2>/dev/null
  local cmd_count=0
  for skill_dir in "$BRAIN/_Skills"/*/; do
    [ -d "$skill_dir" ] || continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ]; then
      ln -s "../../_Skills/$skill_name/SKILL.md" "$CMD_DIR/$skill_name.md"
      cmd_count=$((cmd_count + 1))
    fi
  done
  echo "  ✓ .claude/commands/: $cmd_count skill symlinks (rebuilt from _Skills/)"

  # Memory: symlink ~/.claude/projects/<hash>/memory/ → _Memory/<slug>/
  local prefix
  prefix=$(echo "$HOME" | tr '/' '-' | sed 's/^-//')
  echo ""
  echo "-- Memory symlinks --"
  for i in "${!SLUGS[@]}"; do
    local slug="${SLUGS[$i]}"
    local code="${CODE_PATHS[$i]}"
    local suffix
    suffix="Development-$(echo "$code" | tr '/' '-')"
    local src="$BRAIN/_Memory/$slug"
    local dest="$CLAUDE_DIR/projects/-${prefix}-$suffix/memory"
    local parent
    parent=$(dirname "$dest")
    mkdir -p "$parent"
    safe_dir_symlink "$src" "$dest"
    echo "  ✓ $slug: memory → $src"
  done
}

echo ""
echo "-- Claude config --"
setup_claude

# --- Code repo symlinks (project_files/brain/) ---

echo ""
echo "-- Brain repo CLAUDE.md --"
# Brain* repos point to their own project CLAUDE.md (global loads separately via ~/.claude/)
for brain_repo in "$DEV"/Brain*; do
  [ -d "$brain_repo/.git" ] || continue
  ln -sfn "_ClaudeSettings/brain/CLAUDE.md" "$brain_repo/CLAUDE.md"
  echo "  ✓ $(basename "$brain_repo")/CLAUDE.md → _ClaudeSettings/brain/CLAUDE.md"
done

echo ""
echo "-- Code repo symlinks --"
for i in "${!SLUGS[@]}"; do
  slug="${SLUGS[$i]}"
  code="${CODE_PATHS[$i]}"
  [ "$slug" = "brain" ] && continue  # Brain has no code repo
  project="$DEV/$code"
  [ -d "$project" ] || { echo "  ⊘ Skipped $slug (repo not cloned)"; continue; }

  pf="$project/project_files"
  brain_dir="$pf/brain"

  # Remove old-style single symlink or legacy notes symlink
  [ -L "$brain_dir" ] && rm "$brain_dir"
  [ -L "$pf/notes" ] && rm "$pf/notes"

  # Create project_files/brain/ as a real directory with per-component symlinks
  mkdir -p "$brain_dir"
  ln -sfn "$BRAIN/_ClaudeSettings/$slug/CLAUDE.md" "$brain_dir/CLAUDE.md"

  # Detect parked vs active for session/status symlinks
  if [ -d "$BRAIN/_ActiveSessions/_Parked/$slug" ]; then
    as_dir="$BRAIN/_ActiveSessions/_Parked/$slug"
  else
    as_dir="$BRAIN/_ActiveSessions/$slug"
  fi
  ln -sfn "$as_dir/session.md" "$brain_dir/session.md"
  ln -sfn "$as_dir/_Status.md" "$brain_dir/_Status.md"

  safe_dir_symlink "$BRAIN/_Memory/$slug" "$brain_dir/memory"
  safe_dir_symlink "$BRAIN/_DevLog/$slug" "$brain_dir/DevLog"
  safe_dir_symlink "$BRAIN/_Workbench/$slug" "$brain_dir/Workbench"
  safe_dir_symlink "$BRAIN/_Docs/$slug" "$brain_dir/_Docs"

  # Root CLAUDE.md → project_files/brain/CLAUDE.md
  ln -sfn "project_files/brain/CLAUDE.md" "$project/CLAUDE.md"

  echo "  ✓ $slug: project_files/brain/ (7 symlinks) + root CLAUDE.md"
done

# --- Collab repo git hooks (pre-push + post-merge) ---

echo ""
echo "-- Collab git hooks --"
for i in "${!SLUGS[@]}"; do
  slug="${SLUGS[$i]}"
  collab="${COLLABS[$i]}"
  code="${CODE_PATHS[$i]}"
  [ "$collab" = "collab" ] || continue
  [ "$slug" = "brain" ] && continue
  project="$DEV/$code"
  hooks_dir="$project/.git/hooks"
  [ -d "$hooks_dir" ] || { echo "  ⊘ Skipped $slug (no .git/hooks)"; continue; }

  # pre-push: block bare pushes; require /push-projectshared (sets ALLOW_COLLAB_PUSH=1)
  cat > "$hooks_dir/pre-push" <<'HOOK'
#!/bin/sh
# Brain vault collab hook — installed by _setup.sh
# Blocks bare git push on collab repos; forces use of /push-projectshared.
if [ "$ALLOW_COLLAB_PUSH" != "1" ]; then
  echo ""
  echo "⚠️  Direct git push blocked on collab repo."
  echo ""
  echo "    This repo is registered as collab in _projects.conf."
  echo "    Use /push-projectshared — it dereferences symlinks, commits,"
  echo "    pushes, and restores symlinks safely."
  echo ""
  echo "    Override (only if you know what you're doing):"
  echo "      ALLOW_COLLAB_PUSH=1 git push ..."
  echo ""
  exit 1
fi
HOOK
  chmod 0755 "$hooks_dir/pre-push"

  # post-merge: detect brain symlinks overwritten by real files after any pull/merge
  cat > "$hooks_dir/post-merge" <<'HOOK'
#!/bin/sh
# Brain vault collab hook — installed by _setup.sh
# Warns if project_files/brain/ symlinks were overwritten with real files.
BRAIN_DIR="project_files/brain"
[ -d "$BRAIN_DIR" ] || exit 0
BROKEN=""
for item in CLAUDE.md session.md _Status.md memory DevLog Workbench _Docs; do
  target="$BRAIN_DIR/$item"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    BROKEN="$BROKEN $item"
  fi
done
if [ -n "$BROKEN" ]; then
  echo ""
  echo "⚠️  Brain symlinks were overwritten by real files after this merge/pull:"
  for b in $BROKEN; do echo "       - $BRAIN_DIR/$b"; done
  echo ""
  echo "    This is a collab repo. To fix: run /pull-projectshared to merge"
  echo "    partner's changes into Brain canonical and restore symlinks."
  echo ""
  echo "    DO NOT push, edit brain files, or run /start-session until resolved."
  echo ""
fi
HOOK
  chmod 0755 "$hooks_dir/post-merge"

  # Mark tracked brain files as assume-unchanged so git ignores the
  # symlink-vs-committed-real-file divergence. Push-projectshared's flow
  # clears these flags, dereferences, commits, pushes, then re-sets them.
  ( cd "$project" && git ls-files project_files/brain/ 2>/dev/null | while read f; do
      git update-index --assume-unchanged "$f" 2>/dev/null || true
    done )

  # Exclude the directory-symlinks locally — they replaced previously-tracked
  # real dirs, so git sees them as untracked. .git/info/exclude silences that.
  exclude="$project/.git/info/exclude"
  for sym in project_files/brain/memory project_files/brain/DevLog; do
    grep -qxF "$sym" "$exclude" 2>/dev/null || echo "$sym" >> "$exclude"
  done

  echo "  ✓ $slug: pre-push + post-merge hooks + assume-unchanged flags"
done

echo ""
echo "Done. To add a new project, add a line to _projects.conf and re-run."
