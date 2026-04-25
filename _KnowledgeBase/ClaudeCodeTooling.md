---
tags: [reference, claude-code]
---

# Claude Code Tooling

Cross-project gotchas specific to Claude Code's built-in tools.

## Gotchas

### Edit tool can replace intermediate symlinks with regular files
**As of:** 2026-04 (Claude Code, observed on macOS Darwin 25.3)

When editing a file reached through a multi-level symlink chain, an intermediate symlink may be replaced with a regular file containing the edited content. The final target is not updated, and the chain is silently broken.

**Observed case** — a project's CLAUDE.md chain:
```
<Project>/CLAUDE.md                                 (symlink, tracked by repo)
  → project_files/brain/CLAUDE.md                   (symlink, in gitignored brain/)
    → <Brain>/_ClaudeSettings/<slug>/CLAUDE.md            (real file, tracked by Brain)
```

After Edit calls targeting the root path, `project_files/brain/CLAUDE.md` became a 2369-byte regular file with the edited content, while the Brain-side real file retained the old content. Two resulting problems:
1. The source of truth (Brain-side) was silently stale.
2. A subsequent read via the root symlink returned the edited content (masking the desync), so the divergence wasn't obvious until comparing both ends.

**Detection** — after Edit-ing through a symlink chain, compare both ends:
```bash
diff -q /path/to/root-symlink /path/to/actual-target
# Empty output means in-sync
```

**Mitigation:**
- Prefer editing the real target directly. Resolve the chain with `realpath <path>` before calling Edit.
- If breakage detected: copy edited content to the real target, `rm` the broken intermediate file, recreate the symlink (`ln -s <abs-target> <intermediate-path>`).

**Open questions:** Reproduction conditions not fully characterized — unclear whether this triggers on every multi-level chain or only under specific circumstances (chain depth, filesystem, atomic-rename semantics). Log conditions when hit.

### GitHub access via `gh mcp` (stdio server)
**As of:** 2026-03 (`shuymn/gh-mcp` v2.1.0)

GitHub access in Claude Code uses the `shuymn/gh-mcp` extension configured as a stdio MCP server (`gh mcp`). Authenticates via the `gh` CLI keyring token — no separate PAT needed.

The old HTTP plugin (`github@claude-plugins-official`) is disabled. Settings block:
```json
"mcpServers": {
  "github": { "type": "stdio", "command": "gh", "args": ["mcp"] }
}
```

If removed from `settings.json` to reduce context bloat (tool list is ~10+ entries), restore via the block above. `gh` CLI itself remains usable from Bash for one-off needs without the MCP.
