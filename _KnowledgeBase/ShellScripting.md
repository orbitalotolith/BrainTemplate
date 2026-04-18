---
tags: [reference, shell, bash]
---

# Shell Scripting

Cross-project gotchas for bash/zsh scripting.

## Gotchas

### `xargs -I{} dirname {}` is unsafe with paths containing spaces
**As of:** bash 3+, zsh (always)
`xargs -I{}` substitutes the entire input including any spaces, but passes it as a single argument only when the shell doesn't re-split. In practice:
```bash
# UNSAFE — breaks if path contains a space
find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d | head -1 | xargs -I{} dirname {}

# SAFE — subshell captures the full path, dirname handles it correctly
dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null
```
The `$()` form passes the full string as one argument to `dirname`. Always prefer this when piping paths.

### Heredoc delimiter conflicts in skill files
**As of:** bash 3+, zsh 5+ (any version supporting heredocs)
When writing SKILL.md files that contain bash heredocs, avoid using `EOF` as the delimiter — it collides with surrounding shell contexts (e.g., when the skill itself is used in a `cat << EOF` block). Use descriptive delimiters:
```bash
cat > "$AS_FILE" << HEREDOC_IMPORT
...
HEREDOC_IMPORT

cat > "$EXPORT_DIR/manifest.json" << MANIFEST
...
MANIFEST
```

### Self-detecting script location (for root-relative paths)
**As of:** bash 3.1+, zsh 4+ (POSIX `$()` subshell required)
Scripts that need to find their own location (e.g., `_setup.sh` finding `_skills/`):
```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
```
This gives the absolute path of the directory containing the script, regardless of how it was called (`bash $BRAIN_ROOT/_setup.sh`, `./setup.sh`, etc.).
