---
tags: [reference, git]
---

# Git

Cross-project gotchas for git usage.

## Gotchas

### gitignore trailing `/` does NOT match symlinks
**As of:** git 2.x (all modern versions)

Git treats symlinks as files (tracked as blobs containing the target path), not directories. A gitignore pattern ending in `/` only matches directories. This means:

```gitignore
# WRONG — won't match symlinks to directories
_Memory/*/

# RIGHT — matches both real directories AND symlinks
_Memory/*
!_Memory/brain
```

This is critical when migrating from real directories to symlinks — `git add -A` will stage the symlinks as new files because the `/`-suffixed ignore pattern no longer matches them. The old real files show as `D` (deleted) and the symlinks show as untracked.

Similarly, `_ActiveSessions/*-as.md` must be used without a trailing `/` since symlinked session files are files to git.

### `git add -A` stages type changes (file → symlink) as delete + add
**As of:** git 2.x

When a tracked file is replaced by a symlink, `git status` shows it as `T` (type change). `git add -A` will stage this as a deletion of the old blob and addition of the new symlink blob. If the symlink should be ignored, the `.gitignore` must cover the path BEFORE running `git add -A`, otherwise the symlink gets staged.

To fix accidentally staged symlinks:
```bash
git reset HEAD <path>
```
Then ensure `.gitignore` covers the pattern, and re-run `git add -A`.

### `**` glob in gitignore matches at any depth
**As of:** git 1.8.2+

`**/` matches zero or more directories. Use this instead of fixed-depth patterns:
```gitignore
# WRONG — only matches exactly 2 levels deep
_Notes/*/*/_Status.md

# RIGHT — matches _Status.md at any depth under _Notes/
_Notes/**/_Status.md
```

This prevents silent failures when project nesting depth changes.
