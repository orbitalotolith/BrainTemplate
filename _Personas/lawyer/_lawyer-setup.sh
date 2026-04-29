#!/bin/bash
# Lawyer-persona setup. Called by _setup.sh after persona unpack.
# Note: this file is unpacked to vault root by _setup.sh, so $BRAIN refers to vault root.
set -e

BRAIN="${BRAIN_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
LEGAL="$HOME/Legal"
MATTERS_CONF="$BRAIN/_matters.conf"

echo ""
echo "-- Lawyer persona setup --"
echo ""

# Write BRAIN_ROOT to shell rc (idempotent)
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

# Create vault directories
echo "-- Vault directories --"
mkdir -p "$BRAIN/_ActiveSessions/_Parked"
mkdir -p "$BRAIN/_AgentTasks"
mkdir -p "$BRAIN/_Profile"
mkdir -p "$BRAIN/_Workbench"
mkdir -p "$BRAIN/_Memory"
mkdir -p "$BRAIN/_KnowledgeBase"
mkdir -p "$BRAIN/_Log"
echo "  ✓ Standard vault directories created"

# Initialize matters.conf if missing
if [ ! -f "$MATTERS_CONF" ]; then
  cat > "$MATTERS_CONF" <<EOF
# Lawyer Matter Registry — _matters.conf
# Format: SLUG|CLIENT|TYPE|EXTERNAL_PATH|STATUS
#   SLUG          — matter identifier (used in _ActiveSessions/, _Memory/, etc.)
#   CLIENT        — client name (free-form)
#   TYPE          — contract | litigation | advisory | drafting | regulatory
#   EXTERNAL_PATH — relative to ~/Legal/ (optional; empty = in-Brain only)
#   STATUS        — active | closed | on-hold
#
# Add entries via /create-matter skill.
EOF
  echo "  ✓ _matters.conf initialized"
fi

# Create ~/Legal/ root if user wants external matters
mkdir -p "$LEGAL"
echo "  ✓ ~/Legal/ ready for external matter folders"

# Profile prompts
echo ""
echo "-- Profile setup --"
echo ""
read -p "Your name: " USER_NAME
read -p "Practice area (e.g., 'corporate transactions', 'litigation'): " PRACTICE_AREA
read -p "Typical matter types (comma-separated, e.g., 'contract,advisory'): " MATTER_TYPES

# Seed _Profile/index.md from Profile-skeleton.md.
# Skip if file exists AND is not a placeholder (preserves user edits on re-run).
# BrainTemplate ships _Profile/index.md as a stub containing "TODO: fill in your" — that's
# treated as not-yet-seeded so first-run setup can replace it.
PROFILE_INDEX="$BRAIN/_Profile/index.md"
SKELETON="$BRAIN/Profile-skeleton.md"
PLACEHOLDER_MARKER="TODO: fill in your"

if [ -f "$PROFILE_INDEX" ] && ! grep -q "$PLACEHOLDER_MARKER" "$PROFILE_INDEX"; then
  echo "  ⊘ _Profile/index.md has user content — keeping (delete to reseed)"
else
  if [ ! -f "$SKELETON" ]; then
    echo "FATAL: Profile-skeleton.md not found at $SKELETON. Lawyer payload may be incomplete."
    exit 1
  fi
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  PROFILE_CONTENT=$(cat "$SKELETON")
  PROFILE_CONTENT="${PROFILE_CONTENT//\{\{CREATED\}\}/$NOW}"
  PROFILE_CONTENT="${PROFILE_CONTENT//\{\{USER_NAME\}\}/$USER_NAME}"
  PROFILE_CONTENT="${PROFILE_CONTENT//\{\{PRACTICE_AREA\}\}/$PRACTICE_AREA}"
  PROFILE_CONTENT="${PROFILE_CONTENT//\{\{MATTER_TYPES\}\}/$MATTER_TYPES}"
  printf '%s\n' "$PROFILE_CONTENT" > "$PROFILE_INDEX"
  rm -f "$SKELETON"  # skeleton consumed; remove to keep vault clean
  if [ -f "${PROFILE_INDEX}.bak" ]; then rm -f "${PROFILE_INDEX}.bak"; fi
  echo "  ✓ _Profile/index.md seeded from Profile-skeleton.md"
fi
echo ""

# Offer first matter
echo "-- First matter (optional) --"
read -p "Create your first matter now? (Y/n): " CREATE_FIRST
if [[ "$CREATE_FIRST" =~ ^[Nn] ]]; then
  echo "  ⊘ Skipped. You can create matters anytime via /create-matter."
else
  read -p "Matter slug (e.g., 'acme-acquisition'): " MATTER_SLUG
  read -p "Client name: " CLIENT
  read -p "Type (contract/litigation/advisory/drafting/regulatory): " MATTER_TYPE
  read -p "Create external folder ~/Legal/$MATTER_SLUG/? (Y/n): " EXT_CHOICE
  EXT_PATH=""
  if [[ ! "$EXT_CHOICE" =~ ^[Nn] ]]; then
    mkdir -p "$LEGAL/$MATTER_SLUG/documents"
    EXT_PATH="$MATTER_SLUG"
    echo "  ✓ ~/Legal/$MATTER_SLUG/documents/ created"
  fi

  # Add to _matters.conf
  echo "$MATTER_SLUG|$CLIENT|$MATTER_TYPE|$EXT_PATH|active" >> "$MATTERS_CONF"

  # Create matter session directory + Status from template
  mkdir -p "$BRAIN/_ActiveSessions/$MATTER_SLUG"
  if [ -f "$BRAIN/_Templates/MatterStatus.md" ]; then
    # Render Status from template (bash parameter expansion is literal — no sed escaping)
    TEMPLATE_CONTENT=$(cat "$BRAIN/_Templates/MatterStatus.md")
    NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    TEMPLATE_CONTENT="${TEMPLATE_CONTENT//\{\{SLUG\}\}/$MATTER_SLUG}"
    TEMPLATE_CONTENT="${TEMPLATE_CONTENT//\{\{CLIENT\}\}/$CLIENT}"
    TEMPLATE_CONTENT="${TEMPLATE_CONTENT//\{\{TYPE\}\}/$MATTER_TYPE}"
    TEMPLATE_CONTENT="${TEMPLATE_CONTENT//\{\{EXTERNAL_PATH\}\}/$EXT_PATH}"
    TEMPLATE_CONTENT="${TEMPLATE_CONTENT//\{\{CREATED\}\}/$NOW}"
    printf '%s\n' "$TEMPLATE_CONTENT" > "$BRAIN/_ActiveSessions/$MATTER_SLUG/_Status.md"
    echo "  ✓ _ActiveSessions/$MATTER_SLUG/_Status.md created from template"
  else
    echo "  ⚠ MatterStatus.md template not found; created empty _Status.md"
    touch "$BRAIN/_ActiveSessions/$MATTER_SLUG/_Status.md"
  fi
fi

echo ""
echo "-- Setup complete --"
echo ""
echo "Open Claude Code in $BRAIN and start working."
echo "Try: /create-matter, /ingest-document, /summarize-document"
