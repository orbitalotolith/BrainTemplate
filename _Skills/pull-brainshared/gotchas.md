# Pull Brain — Gotchas

## Hardcoded path list missed renames (2026-04-04)

**What happened:** Partner renamed `claude-settings/` → `_ClaudeSettings/` in BrainShared. Pull
tried to `cp` to `_ClaudeSettings/CLAUDE.md` but the directory didn't exist locally (no `mkdir -p`),
so the copy silently failed. The old `claude-settings/` was never cleaned up because pull only
synced paths from a hardcoded `SHARED_PATHS` list — it never asked "what's in my local Brain that
isn't in BrainShared?"

**Root cause:** Inclusion-based path list. Any rename, new directory, or structural change by the
partner was invisible unless someone manually updated the path list in the skill definition.

**Fix:** Replaced inclusion list with repo-driven sync. Pull now scans BrainShared's actual contents
and syncs everything found. Stale path detection was later removed (see 2026-04-09 gotcha).

**Rule:** BrainShared's repo contents ARE the definition of what's shared. Never hardcode the list.

## Mixed directory protection requires shell-portable array handling (2026-04-10)

**What happened:** Two related failures. First (2026-04-09): `_ClaudeSettings/` contains both
shared content (`global/`) and local content (per-project slug directories). The sync algorithm
used `rsync --delete` on the entire directory, deleting 9 per-project CLAUDE.md files. Second
(2026-04-10): the fix introduced a `MIXED_DIRS` concept using a space-delimited string
(`MIXED_DIRS="_ClaudeSettings _Memory"`) with `for md in $MIXED_DIRS`. In zsh (Claude Code's
default shell) this never splits — the `is_mixed` check always returned false, so every
directory still fell through to `rsync --delete`. Wiped 6 more per-project CLAUDE.md files and
6 agentdashboard memory files.

**Root cause:** Mixed directory protection requires both the concept (MIXED_DIRS) and the
implementation (array syntax) to be correct. The concept was missing initially, and once added,
the implementation used bash-only string splitting that silently failed in zsh.

**Fix:** (1) Added `MIXED_DIRS` concept — mixed directories are synced at the subdirectory level,
with `--delete` only within subdirectories present in BrainShared. Local-only subdirectories are
untouched. (2) Changed from space-delimited string to a shell array:
`MIXED_DIRS=(_ClaudeSettings _Memory)`, iterated with `"${ARRAY[@]}"`. Arrays work identically
in both shells.

**Also removed:** Stale path detection. The premise ("not in BrainShared = stale") was wrong
because the local Brain has many legitimate paths that were never shared (`_Docs/`, `_Dashboard.md`,
`CLAUDE.md` symlink, etc.).

**Rules:**
- Never `rsync --delete` a directory that contains both shared and local content. Sync at the
  subdirectory level for mixed directories.
- Never use space-delimited strings for lists in skill bash snippets. Use arrays with
  `"${ARRAY[@]}"` — they're portable across bash and zsh.
