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

### `git merge` auto-stash fails through symlink boundaries; `git checkout --` still works
**As of:** git 2.x (observed 2026-04-22)

When merging with a dirty working tree, git internally runs `stash` to save state. If the tree contains tracked files whose paths traverse a symlinked directory, the stash fails with:

```
error: '<path>' is beyond a symbolic link
fatal: Unable to process path <path>
Cannot save the current worktree state
fatal: stash failed
```

Common trigger: vault/note symlinks like `project_files/brain/DevLog -> /elsewhere/_DevLog/<slug>/` where git also has tracked blobs committed at `project_files/brain/DevLog/*.md` from a prior collab sync.

Escape hatch: `git checkout -- <symlinked-path>` can restore those files through the symlink (it only writes the tracked blobs to their in-tree paths, doesn't traverse any directory). Clears the "D" deletions git is seeing. Then retry the merge.

```bash
# FAIL — stash can't traverse symlink
git merge --no-ff feature
# Cannot save the current worktree state
# fatal: stash failed

# RIGHT — restore tracked blobs, then merge
git checkout -- project_files/brain/
git merge --no-ff feature   # clean worktree now, no stash needed
```

### `git worktree remove` refuses worktrees with untracked files (including symlinks)
**As of:** git 2.x

`git worktree remove <path>` aborts with `fatal: '<path>' contains modified or untracked files, use --force to delete it` if the worktree has ANY untracked files — not just real files with data, but symlinks too. Common trigger: a worktree-local `.venv` symlink pointing to the main repo's venv (convention for sharing virtualenvs across worktrees).

```bash
# FAIL — won't remove due to untracked .venv symlink
git worktree remove .worktrees/my-branch
# fatal: '.worktrees/my-branch' contains modified or untracked files, use --force to delete it

# RIGHT — rm the symlink first (removes the link, NOT its target), then remove the worktree
rm .worktrees/my-branch/.venv
git worktree remove .worktrees/my-branch
```

`--force` would also work but swallows any genuinely unexpected untracked work in the worktree. Explicit `rm` on known-safe paths keeps the safety net for real surprises.
