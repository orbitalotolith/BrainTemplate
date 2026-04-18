# Push Brain — Gotchas

## Stale shared paths after renames (2026-04-04)

**What happened:** Local Brain renamed `claude-settings/` to `_ClaudeSettings/`. The push
copied `_ClaudeSettings/CLAUDE.md` to shared but never checked whether the old
`claude-settings/` directory still existed in BrainShared. Result: shared repo had both
paths — the old one orphaned.

**Root cause:** Both push and pull used a hardcoded `SHARED_PATHS` inclusion list. Any
rename, new directory, or structural change was invisible to both skills.

**Fix:** Replaced `SHARED_PATHS` inclusion list with a `PRIVATE_PATTERN` exclusion list.
Push now diffs ALL non-private local files against BrainShared. The reverse scan catches
paths that exist remotely but not locally. The early exit ("Nothing to push") no longer
bypasses the reverse scan — push always clones BrainShared and runs the full diff.

**Rule:** BrainShared's repo contents define what's shared. Use exclusion (private paths)
not inclusion (shared paths). Never exit early before comparing both sides.

## LAST_PUSH_COMMIT is a remote hash (2026-04-04)

**What happened:** `LAST_PUSH_COMMIT` stored a BrainShared commit hash, but `git diff` used
it against the local Brain repo where that hash doesn't exist. The diff silently failed,
making change detection return empty results every time.

**Fix:** Added `LAST_LOCAL_PUSH_COMMIT` field to `_sync.conf`. (`LAST_LOCAL_PULL_COMMIT` was later removed — pulls don't commit.)
Local diffs use the local hash. Remote comparisons use the BrainShared hash.

**Rule:** Always use the correct commit hash for the repo you're diffing against.

## Identity memories leaked to BrainShared (2026-04-05) — RESOLVED 2026-04-06

**What happened:** `user_role.md`, `user_profile.md`, and `user_workflow.md` were committed
in BrainShared's `_Memory/brain/`. Identity memories are private and should never have been pushed.

**Fix:** Added `_Memory/brain/user_*.md` to `PRIVATE_PATTERN`, Step 8 safety check, and
BrainShared's `.gitignore`. Deleted the files from BrainShared on 2026-04-06 push.
