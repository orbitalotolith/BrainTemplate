#!/bin/bash
# Verify the Brain vault system is wired correctly (Brain-canonical architecture).
# Brain holds all real files; code repos contain symlinks pointing into Brain.
# Run: bash $BRAIN_ROOT/_health-check.sh
set -e

BRAIN="${BRAIN_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
DEV="$HOME/Development"
CLAUDE_DIR="$HOME/.claude"
CONF="$BRAIN/_projects.conf"
PASS=0
WARN=0
FAIL=0

pass() { echo "  OK    $1"; PASS=$((PASS + 1)); }
warn() { echo "  WARN  $1"; WARN=$((WARN + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

# --- Parse project registry ---

if [ ! -f "$CONF" ]; then
  echo "FATAL: _projects.conf not found at $CONF"
  exit 1
fi

SLUGS=()
CATEGORIES=()
CODE_PATHS=()
COLLAB_FLAGS=()
while IFS='|' read -r slug category code collab; do
  [[ "$slug" =~ ^#.*$ || -z "$slug" ]] && continue
  SLUGS+=("$slug")
  CATEGORIES+=("$category")
  CODE_PATHS+=("$code")
  COLLAB_FLAGS+=("${collab:-}")
done < "$CONF"

echo "=== Brain Vault Health Check (Brain-Canonical) ==="
echo "Registry: ${#SLUGS[@]} projects in _projects.conf"
echo ""

# --- 1. Core directories ---

echo "-- Core directories --"
for dir in "$BRAIN/_Workbench" "$BRAIN/_KnowledgeBase" "$BRAIN/_DevLog" \
           "$BRAIN/_ClaudeSettings" "$BRAIN/_Memory" \
           "$BRAIN/_Skills" "$BRAIN/_Templates" \
           "$BRAIN/_ActiveSessions" "$BRAIN/_Profile" \
           "$BRAIN/_Docs" "$BRAIN/_Agents"; do
  if [ -d "$dir" ]; then
    pass "$(basename "$dir")/"
  else
    fail "$dir missing"
  fi
done

# --- 1b. Agent directories ---

echo ""
echo "-- Agent directories --"
if [ -d "$BRAIN/_Agents" ]; then
  agent_count=0
  for adir in "$BRAIN/_Agents"/*/; do
    [ -d "$adir" ] || continue
    aname=$(basename "${adir%/}")
    if [ -f "$adir/persona.yaml" ]; then
      pass "agent '$aname' has persona.yaml"
      agent_count=$((agent_count + 1))
    else
      fail "agent '$aname' missing persona.yaml"
    fi
    if [ ! -d "$adir/memory" ]; then
      warn "agent '$aname' missing memory/ directory"
    fi
  done
  if [ "$agent_count" -eq 0 ]; then
    warn "_Agents/ contains no agents (informational)"
  fi
fi

# --- 2. Core files ---

echo ""
echo "-- Core files --"
for file in "$BRAIN/_projects.conf" "$BRAIN/WordOfWisdom.md" \
            "$BRAIN/_HowThisWorks.md" "$BRAIN/key-to-dev.md" \
            "$BRAIN/_setup.sh" "$BRAIN/_health-check.sh"; do
  if [ -f "$file" ]; then
    pass "$(basename "$file")"
  else
    fail "$(basename "$file") missing"
  fi
done

# --- 3. Brain-side real files (must NOT be symlinks) ---

echo ""
echo "-- Brain canonical files --"
for i in "${!SLUGS[@]}"; do
  slug="${SLUGS[$i]}"
  code="${CODE_PATHS[$i]}"
  [ "$slug" = "brain" ] && continue

  # _ClaudeSettings/<slug>/CLAUDE.md — real file in Brain
  cs_file="$BRAIN/_ClaudeSettings/$slug/CLAUDE.md"
  if [ -f "$cs_file" ] && [ ! -L "$cs_file" ]; then
    pass "$slug: _ClaudeSettings CLAUDE.md (real file)"
  elif [ -L "$cs_file" ]; then
    fail "$slug: _ClaudeSettings CLAUDE.md is a symlink (should be real)"
  else
    fail "$slug: _ClaudeSettings/$slug/CLAUDE.md missing"
  fi

  # _Memory/<slug>/ — real directory in Brain
  mem_dir="$BRAIN/_Memory/$slug"
  if [ -d "$mem_dir" ] && [ ! -L "$mem_dir" ]; then
    pass "$slug: _Memory/$slug (real directory)"
    [ -f "$mem_dir/MEMORY.md" ] && pass "$slug: MEMORY.md exists" || fail "$slug: MEMORY.md missing"
  elif [ -L "$mem_dir" ]; then
    fail "$slug: _Memory/$slug is a symlink (should be real dir)"
  else
    fail "$slug: _Memory/$slug missing"
  fi

  # _ActiveSessions/<slug>/ — real files
  as_dir="$BRAIN/_ActiveSessions/$slug"
  parked_dir="$BRAIN/_ActiveSessions/_Parked/$slug"
  check_dir=""
  [ -d "$as_dir" ] && check_dir="$as_dir"
  [ -d "$parked_dir" ] && check_dir="$parked_dir"

  if [ -z "$check_dir" ]; then
    fail "$slug: no _ActiveSessions directory"
  else
    # session.md — must be real file, NOT symlink
    if [ -f "$check_dir/session.md" ] && [ ! -L "$check_dir/session.md" ]; then
      pass "$slug: AS session.md (real file)"
    elif [ -L "$check_dir/session.md" ]; then
      fail "$slug: AS session.md is a symlink (should be real)"
    else
      fail "$slug: AS session.md missing"
    fi

    # _Status.md — must be real file, NOT symlink
    if [ -f "$check_dir/_Status.md" ] && [ ! -L "$check_dir/_Status.md" ]; then
      pass "$slug: AS _Status.md (real file)"
    elif [ -L "$check_dir/_Status.md" ]; then
      fail "$slug: AS _Status.md is a symlink (should be real)"
    else
      fail "$slug: AS _Status.md missing"
    fi
  fi

  # _DevLog/<slug>/ — real directory
  devlog_dir="$BRAIN/_DevLog/$slug"
  if [ -d "$devlog_dir" ] && [ ! -L "$devlog_dir" ]; then
    pass "$slug: _DevLog/$slug (real directory)"
  elif [ -L "$devlog_dir" ]; then
    fail "$slug: _DevLog/$slug is a symlink (should be real dir)"
  else
    warn "$slug: _DevLog/$slug missing"
  fi

  # _Workbench/<slug>/ — real directory
  wb_dir="$BRAIN/_Workbench/$slug"
  if [ -d "$wb_dir" ] && [ ! -L "$wb_dir" ]; then
    pass "$slug: _Workbench/$slug (real directory)"
  elif [ -L "$wb_dir" ]; then
    fail "$slug: _Workbench/$slug is a symlink (should be real dir)"
  else
    warn "$slug: _Workbench/$slug missing"
  fi
done

# --- 4. Code repo symlinks (must point to Brain) ---

echo ""
echo "-- Code repo symlinks (→ Brain) --"
for i in "${!SLUGS[@]}"; do
  slug="${SLUGS[$i]}"
  code="${CODE_PATHS[$i]}"
  [ "$slug" = "brain" ] && continue

  project="$DEV/$code"
  brain_dir="$project/project_files/brain"

  if [ ! -d "$project" ]; then
    warn "$slug: repo not cloned (skipped)"
    continue
  fi

  if [ ! -d "$brain_dir" ]; then
    fail "$slug: project_files/brain/ missing"
    continue
  fi

  # Each item in project_files/brain/ should be a symlink pointing to Brain
  check_symlink() {
    local path="$1" expected="$2" label="$3"
    if [ -L "$path" ]; then
      actual=$(readlink "$path")
      if [ "$actual" = "$expected" ]; then
        if [ -e "$path" ]; then
          pass "$slug: $label → Brain"
        else
          fail "$slug: $label → Brain target missing or unresolvable (expected $expected)"
        fi
      else
        fail "$slug: $label wrong target (→ $actual)"
      fi
    elif [ -e "$path" ]; then
      fail "$slug: $label is NOT a symlink (should point to Brain)"
    else
      fail "$slug: $label missing"
    fi
  }

  check_symlink "$brain_dir/CLAUDE.md" "$BRAIN/_ClaudeSettings/$slug/CLAUDE.md" "CLAUDE.md"
  check_symlink "$brain_dir/memory" "$BRAIN/_Memory/$slug" "memory"

  # Accept either active or parked path for session/status symlinks
  if [ -d "$BRAIN/_ActiveSessions/_Parked/$slug" ]; then
    as_dir="$BRAIN/_ActiveSessions/_Parked/$slug"
  else
    as_dir="$BRAIN/_ActiveSessions/$slug"
  fi
  check_symlink "$brain_dir/session.md" "$as_dir/session.md" "session.md"
  check_symlink "$brain_dir/_Status.md" "$as_dir/_Status.md" "_Status.md"

  check_symlink "$brain_dir/DevLog" "$BRAIN/_DevLog/$slug" "DevLog"
  check_symlink "$brain_dir/Workbench" "$BRAIN/_Workbench/$slug" "Workbench"

  # Root CLAUDE.md should chain through project_files/brain/
  root_claude="$project/CLAUDE.md"
  if [ -L "$root_claude" ]; then
    target=$(readlink "$root_claude")
    if [ "$target" = "project_files/brain/CLAUDE.md" ]; then
      pass "$slug: root CLAUDE.md chain valid"
    else
      fail "$slug: root CLAUDE.md wrong target: $target"
    fi
  else
    fail "$slug: root CLAUDE.md is not a symlink"
  fi
done

# --- 5. Project doc directories ---

echo ""
echo "-- Project doc directories --"
for i in "${!SLUGS[@]}"; do
  slug="${SLUGS[$i]}"
  code="${CODE_PATHS[$i]}"
  doc_dir="$BRAIN/_Docs/$slug"

  missing=""
  for subdir in Plans Reports; do
    if [ ! -d "$doc_dir/$subdir" ]; then
      missing="$missing $subdir"
    fi
  done
  if [ -n "$missing" ]; then
    fail "$slug: _Docs/$slug/ missing subdirs:$missing (run _setup.sh)"
    continue
  fi

  if [ "$slug" = "brain" ]; then
    pass "$slug: _Docs/$slug/ exists with all subdirs"
  elif [ ! -d "$DEV/$code" ]; then
    warn "$slug: repo not cloned (skipped doc access check)"
  else
    # Verify _Docs is accessible via symlink in project_files/brain/
    access_path="$DEV/$code/project_files/brain/_Docs/Plans"
    if [ -d "$access_path" ]; then
      pass "$slug: _Docs accessible via project_files/brain/_Docs/"
    elif [ -d "$DEV/$code/project_files/brain" ]; then
      if [ ! -L "$DEV/$code/project_files/brain/_Docs" ]; then
        warn "$slug: _Docs symlink missing in project_files/brain/ (run _setup.sh)"
      else
        fail "$slug: _Docs symlink broken in project_files/brain/"
      fi
    else
      fail "$slug: project_files/brain/ missing entirely"
    fi
  fi
done

# --- 6. Claude config symlinks ---

echo ""
echo "-- Claude config symlinks --"
EXPECTED_LINKS=(
  "CLAUDE.md:$BRAIN/_ClaudeSettings/global/CLAUDE.md"
  "settings.json:$BRAIN/_ClaudeSettings/global/settings.json"
  "skills:$BRAIN/_Skills"
)
for pair in "${EXPECTED_LINKS[@]}"; do
  name="${pair%%:*}"
  expected="${pair#*:}"
  link="$CLAUDE_DIR/$name"
  if [ -L "$link" ]; then
    actual=$(readlink "$link")
    if [ "$actual" = "$expected" ]; then
      pass "~/.claude/$name"
    else
      warn "~/.claude/$name -> $actual (expected $expected)"
    fi
  elif [ -e "$link" ]; then
    warn "~/.claude/$name exists but is not a symlink"
  else
    fail "~/.claude/$name missing (run _setup.sh)"
  fi
done

# --- 7. Claude memory symlinks (→ Brain, one hop) ---

echo ""
echo "-- Claude memory symlinks (→ Brain) --"
prefix=$(echo "$HOME" | tr '/' '-' | sed 's/^-//')
for i in "${!SLUGS[@]}"; do
  slug="${SLUGS[$i]}"
  code="${CODE_PATHS[$i]}"
  suffix="Development-$(echo "$code" | tr '/' '-')"
  claude_memory="$CLAUDE_DIR/projects/-${prefix}-$suffix/memory"
  brain_memory="$BRAIN/_Memory/$slug"

  if [ ! -d "$DEV/$code" ]; then
    warn "$slug: repo not cloned (skipped memory check)"
    continue
  fi

  # Claude memory should be a symlink to Brain _Memory/<slug>
  if [ -L "$claude_memory" ]; then
    actual=$(readlink "$claude_memory")
    if [ "$actual" = "$brain_memory" ]; then
      pass "$slug: Claude memory → Brain"
    else
      fail "$slug: Claude memory wrong target (→ $actual, expected → $brain_memory)"
    fi
  elif [ -d "$claude_memory" ]; then
    fail "$slug: Claude memory is a real dir (should be symlink → Brain)"
  else
    warn "$slug: Claude memory dir missing (run _setup.sh)"
  fi
done

# --- 8. Memory coverage ---

echo ""
echo "-- Memory coverage --"
# iterate the dir itself (not glob /*/) so dead symlinks are visible too
# valid _Memory/<name>/ = (name is a project slug) OR (_Agents/<name>/ exists — persona memory pool)
for entry in "$BRAIN/_Memory"/*; do
  [ -e "$entry" ] || [ -L "$entry" ] || continue
  subdir=$(basename "$entry")
  found=false
  source=""
  for s in "${SLUGS[@]}"; do
    if [ "$s" = "$subdir" ]; then
      found=true
      source="project slug"
      break
    fi
  done
  if ! $found && [ -d "$BRAIN/_Agents/$subdir" ]; then
    found=true
    source="agent persona"
  fi
  if ! $found; then
    fail "$subdir exists in _Memory/ but is NOT in _projects.conf and no _Agents/$subdir/ exists"
    continue
  fi
  # Dead symlink or cycle — -L true, -e false
  if [ -L "$entry" ] && [ ! -e "$entry" ]; then
    fail "$subdir: _Memory/$subdir is a dead symlink (target missing or cycle: → $(readlink "$entry"))"
  else
    pass "$subdir in registry ($source)"
  fi
done

# --- 9. Orphaned project directories ---

echo ""
echo "-- Orphaned project detection --"
for dir in "$BRAIN/_Workbench"/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "${dir%/}")
  found=false
  for s in "${SLUGS[@]}"; do
    [ "$s" = "$name" ] && found=true && break
  done
  $found && pass "$name: registered" || warn "$name: exists in _Workbench/ but NOT in _projects.conf"
done

# --- 10. ActiveSession coverage ---

echo ""
echo "-- ActiveSession coverage --"
for slug in "${SLUGS[@]}"; do
  active_dir="$BRAIN/_ActiveSessions/$slug"
  parked_dir="$BRAIN/_ActiveSessions/_Parked/$slug"
  if [ -d "$active_dir" ]; then
    pass "$slug: session directory exists (active)"
  elif [ -d "$parked_dir" ]; then
    pass "$slug: session directory exists (parked)"
  else
    warn "$slug: no session directory in _ActiveSessions/ or _Parked/"
  fi
done

for dir in "$BRAIN/_ActiveSessions"/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  [ "$name" = "_Parked" ] && continue
  found=false
  for s in "${SLUGS[@]}"; do
    [ "$s" = "$name" ] && found=true && break
  done
  $found || warn "$name: directory in _ActiveSessions/ but slug NOT in _projects.conf"
done
for dir in "$BRAIN/_ActiveSessions/_Parked"/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  found=false
  for s in "${SLUGS[@]}"; do
    [ "$s" = "$name" ] && found=true && break
  done
  $found || warn "$name: directory in _Parked/ but slug NOT in _projects.conf"
done

# --- 11. Hardcoded Brain names in infrastructure scripts ---

echo ""
echo "-- Hardcoded Brain names in scripts --"
for script in "$BRAIN/_setup.sh" "$BRAIN/_health-check.sh"; do
  sname=$(basename "$script")
  # Look for literal Brain directory name (the actual dir name, not $BRAIN/$BRAIN_ROOT vars)
  brain_dirname=$(basename "$BRAIN")
  # Skip if brain_dirname is generic (e.g., "Brain" — too many false positives)
  if [ -n "$brain_dirname" ] && [ "$brain_dirname" != "." ]; then
    # Find lines with the literal Brain dir name that aren't variable references or comments
    matches=$(grep -n "$brain_dirname" "$script" 2>/dev/null | grep -v '^\s*#' | grep -v '\$BRAIN' | grep -v 'BRAIN_ROOT' | grep -v 'basename' || true)
    if [ -n "$matches" ]; then
      warn "$sname contains hardcoded Brain directory name '$brain_dirname' — use \$BRAIN or \$BRAIN_ROOT instead"
    else
      pass "$sname: no hardcoded Brain names"
    fi
  fi
done

# --- 11b. Empty _ClaudeSettings subdirectories ---

echo ""
echo "-- ClaudeSettings empty subdirs --"
empty_cs=false
for dir in "$BRAIN/_ClaudeSettings"/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
    warn "_ClaudeSettings/$name/ is empty (migration artifact?)"
    empty_cs=true
  fi
done
if ! $empty_cs; then
  pass "_ClaudeSettings: no empty subdirectories"
fi

# --- 12. WordOfWisdom drift check (was 11) ---

echo ""
echo "-- WordOfWisdom integrity --"
WOW_FILE="$BRAIN/WordOfWisdom.md"
CLAUDE_MD="$BRAIN/_ClaudeSettings/global/CLAUDE.md"
if [ -f "$WOW_FILE" ] && [ -f "$CLAUDE_MD" ]; then
  # Extract keyword only (strip number prefix and markdown formatting) so the check
  # works regardless of whether CLAUDE.md uses "## 1. Honesty" or "1. **Honesty**" format.
  wow_keywords=$(grep '^## ' "$WOW_FILE" | sed 's/^## //' | sed 's/^[0-9]*\. //' | head -10)
  drift=false
  while IFS= read -r keyword; do
    [ -z "$keyword" ] && continue
    if ! grep -qF "$keyword" "$CLAUDE_MD"; then
      fail "WordOfWisdom principle '$keyword' missing from CLAUDE.md"
      drift=true
    fi
  done <<< "$wow_keywords"
  if ! $drift; then
    pass "WordOfWisdom headings present in CLAUDE.md"
  fi
else
  [ ! -f "$WOW_FILE" ] && fail "WordOfWisdom.md missing"
  [ ! -f "$CLAUDE_MD" ] && fail "claude-settings/CLAUDE.md missing"
fi

# --- 13. Sync config validation (was 12) ---

echo ""
echo "-- Sync config --"
SYNC_CONF="$BRAIN/_sync.conf"
if [ -f "$SYNC_CONF" ]; then
  source "$SYNC_CONF"
  pass "_sync.conf exists"

  if [ -n "${SHARED_BRAIN_REMOTE:-}" ]; then
    pass "SHARED_BRAIN_REMOTE set"
  else
    fail "SHARED_BRAIN_REMOTE not set in _sync.conf"
  fi

  if [ -n "${SHARED_ORG:-}" ]; then
    pass "SHARED_ORG set"
  else
    warn "SHARED_ORG not set (needed for /share-project)"
  fi

  if [ -n "${SYNC_IDENTITY:-}" ]; then
    pass "SYNC_IDENTITY set"
  else
    warn "SYNC_IDENTITY not set (needed for session.md section headers)"
  fi

  if [ -n "${LAST_PUSH_DATE:-}" ]; then
    days_since_push=$(( ( $(date +%s) - $(date -j -f "%Y-%m-%d" "$LAST_PUSH_DATE" +%s 2>/dev/null || echo 0) ) / 86400 ))
    if [ "$days_since_push" -gt 7 ] 2>/dev/null; then
      warn "Last push was $days_since_push days ago ($LAST_PUSH_DATE)"
    else
      pass "Last push: $LAST_PUSH_DATE"
    fi
  else
    warn "No push recorded yet"
  fi

  if [ -n "${LAST_PULL_DATE:-}" ]; then
    days_since_pull=$(( ( $(date +%s) - $(date -j -f "%Y-%m-%d" "$LAST_PULL_DATE" +%s 2>/dev/null || echo 0) ) / 86400 ))
    if [ "$days_since_pull" -gt 7 ] 2>/dev/null; then
      warn "Last pull was $days_since_pull days ago ($LAST_PULL_DATE)"
    else
      pass "Last pull: $LAST_PULL_DATE"
    fi
  else
    warn "No pull recorded yet"
  fi

  # Collab projects must have a SHARED_PROJECTS entry
  for i in "${!SLUGS[@]}"; do
    [ "${COLLAB_FLAGS[$i]}" = "collab" ] || continue
    slug="${SLUGS[$i]}"
    found=false
    for entry in "${SHARED_PROJECTS[@]}"; do
      entry_slug="${entry%%|*}"
      if [ "$entry_slug" = "$slug" ]; then
        found=true
        break
      fi
    done
    if $found; then
      pass "$slug: collab project registered in SHARED_PROJECTS"
    else
      fail "$slug: marked collab in _projects.conf but missing from SHARED_PROJECTS in _sync.conf"
    fi
  done
else
  warn "_sync.conf not found (copy _sync.conf.template to set up sync)"
fi

# --- Summary ---

echo ""
echo "=== Results: $PASS passed, $WARN warnings, $FAIL failures ==="
if [ "$FAIL" -gt 0 ]; then
  echo "Run 'bash $BRAIN/_setup.sh' to fix most issues."
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo "Warnings are informational (e.g., repos not cloned on this machine)."
  exit 0
else
  echo "All checks passed."
  exit 0
fi
