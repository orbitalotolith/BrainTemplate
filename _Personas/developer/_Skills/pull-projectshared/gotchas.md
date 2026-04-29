# Gotchas — pull-projectshared

Known design tensions and failure modes. Read before executing.

- **assume-unchanged ordering:** Same as push — flags must stay set during pull. Clear after. Clearing before pull causes git to see symlinks as local modifications and refuse the pull.

- **Symlink vs real file:** Cannot `git diff` working tree when symlinks are present. Unpushed-change check compares Brain canonical files against `git show` of committed versions, not working tree.

- **Memory must be additive:** Never `rm -rf` or `rsync --delete` on memory/DevLog/Workbench dirs. Use `cp -n` for files, auto-merge for MEMORY.md index.

- **First pull:** No LAST_PUSH_COMMIT means no baseline for unpushed-change detection. Skip the check — can't have unpushed changes if you've never pushed.

- **MEMORY.md index:** `cp -n` alone preserves local index but drops partner's new entries. Must auto-merge (combine, deduplicate, sort).
