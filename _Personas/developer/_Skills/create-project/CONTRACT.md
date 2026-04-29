# Contract — create-project

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | MUST NOT overwrite existing files. If a file already exists (CLAUDE.md, _Status.md, .gitignore, etc.), skip it and note what was skipped. |
| 2  | _projects.conf is the single source of truth. MUST add exactly one line per project. All consumers read from this file automatically — no other registry files to update. |
| 3  | MUST run _setup.sh to create symlinks. Never manually create project_files/brain symlinks. |
| 4  | MUST run _health-check.sh after setup to verify the project was wired correctly. |
| 5  | MUST create _Memory/<slug>/MEMORY.md, _ActiveSessions/<slug>/ directory (with session.md and _Status.md symlinks), and _Workbench/<slug> symlink for every new project. No project without a memory seed, session directory, and workbench link. |
| 6  | MUST create _AgentTasks/<slug>/Plans/ directory. No project without a plans directory. |
| 7  | MUST create project_files/data/ directory in code repo. Runtime data goes here, never at project root. |
