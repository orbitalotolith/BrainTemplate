# vault-migrate — Gotchas

## 2026-04-08: Regex patterns need per-line confirmation
**Problem:** Auto-replacing inside regex patterns like push-brain's `PRIVATE_PATTERN` can break regex syntax. A bare directory name inside `^(_Profile/|_projects\.conf$)` needs context-aware replacement.
**Root cause:** Regex metacharacters (`^`, `$`, `|`, `()`) surround the match, and naive replacement can break grouping or escaping.
**Rule:** Never auto-replace matches classified as regex context. Always show the full regex line and get per-line confirmation.

## 2026-04-08: _ActiveSessions rename is catastrophic [absorbed]
**Problem:** `_ActiveSessions` is the Brain root detection marker used by 17+ skills via `find ... -name '_ActiveSessions'`. Renaming it breaks Brain detection everywhere.
**Root cause:** Brain root detection falls back to filesystem scan when `$BRAIN_ROOT` is not set. The scan looks for a directory literally named `_ActiveSessions`.
**Rule:** If a mapping includes `_ActiveSessions`, emit a HIGH severity warning explaining the blast radius. Suggest the user also update their shell config to set `$BRAIN_ROOT` explicitly so detection no longer depends on this directory name.

## 2026-04-08: Code repos need scanning for project_files/brain changes
**Problem:** `project_files/brain/` appears in code repo `.gitignore` files, `CLAUDE.md` files, and `_setup.sh` symlink targets. A rename here affects every project, not just the Brain vault.
**Root cause:** The path `project_files/brain/` is a convention used in every code repo. It's referenced in gitignore patterns, symlink creation, and project CLAUDE.md files.
**Rule:** When a mapping includes `project_files/brain`, scan all registered code repos (via `_projects.conf`) for `.gitignore` and `CLAUDE.md` references in addition to the vault scan.

## 2026-04-08: Must match all path prefix variants
**Problem:** A directory name like `_Profile` appears in multiple forms: bare (`_Profile`), prefixed (`$BRAIN/_Profile`, `$BRAIN_ROOT/_Profile`), relative (`../_Profile`), and in prose without path separators.
**Root cause:** Skills, docs, and scripts reference paths in different styles depending on context.
**Rule:** When scanning, search for the bare name (e.g., `_Profile`) which catches all variants. When replacing, preserve the surrounding path context — only replace the directory name portion.

## 2026-04-08: _HowThisWorks.md changes affect folder-audit behavior
**Problem:** `/folder-audit` reads `_HowThisWorks.md` at runtime as its source of truth. If vault-migrate updates the doc incorrectly, folder-audit starts enforcing wrong rules.
**Root cause:** `_HowThisWorks.md` is the canonical structural reference. Multiple skills depend on it being accurate.
**Rule:** After updating `_HowThisWorks.md` (Phase 5), review the Folder Layout section carefully. Verify it matches the actual filesystem. Recommend running `/folder-audit` after migration to confirm consistency.

## 2026-04-09: Plans must be executable without context loss [absorbed]
**Problem:** If the migration plan doesn't include enough context (current state, target state, exact paths), the agent executing it via superpowers:executing-plans won't have the analysis context and will make wrong assumptions.
**Root cause:** Plan execution happens in a separate session from plan generation. The executing agent only sees the plan file.
**Rule:** Every plan step must be self-contained: include the exact current state, the exact target state, the exact command or edit, and the verification criteria. Never assume the executor "knows" what the analyzer discovered.

## 2026-04-09: Pre-push mode must not plan BrainShared modifications
**Problem:** In pre-push mode, the skill verifies local consistency. If it generates steps that modify `_BrainShared/` content, it conflicts with `/push-brainshared` which owns that directory.
**Root cause:** `_BrainShared/` is managed by push/pull skills. vault-migrate should only read it for comparison.
**Rule:** In pre-push mode, only generate plan steps that modify the local vault (`$BRAIN/` excluding `_BrainShared/`). Flag inconsistencies between local and BrainShared for the user to resolve via push.
