# Gotchas — push-projectshared

Known design tensions and failure modes. Read before executing.

- **assume-unchanged ordering:** Flags must stay set during `git pull --ff-only`. Clearing before pull causes git to see symlinks as local modifications and refuse the pull when partner changed brain files. Clear only after pull completes.

- **Own commit:** push-projectshared does its own git commit (doesn't invoke `/commit`) because `/commit` blocks `project_files/` staging. Safety checks are replicated from `/commit`'s hygiene rules.

- **Stale LAST_PUSH_COMMIT:** If LAST_PUSH_COMMIT is no longer in remote history (force push, rebase), `git diff` against it fails. Fallback: treat as first push, full interactive review.

- **First push:** No LAST_PUSH_COMMIT means no baseline for partner detection. All remote brain file diffs are treated as partner changes to avoid silently overwriting partner's initial setup.
