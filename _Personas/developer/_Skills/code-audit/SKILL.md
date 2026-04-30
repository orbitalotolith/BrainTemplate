---
name: code-audit
description: Audit codebase for shared types, duplicates, naming, quality, dead code, and root hygiene
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Glob, Grep, Read, Write, Edit, AskUserQuestion
---

# Code Audit

Project-type-agnostic code quality audit. Finds issues and fixes them (or reports in dry-run mode). For security, dependency, and deployment checks, use `/security-audit`. See CLAUDE.md "Workflow Conventions" for standard paths.

## Overview

[TBD]

## Arguments

- `--dry-run` — report issues without making changes
- `--types-only` — only audit shared types consistency (section 1)
- `--dead-code` — trace import graph from entry points, report unreachable files/folders and unused exports (section 7)
- `--scope <path>` — limit audit to specific files or directories
- `--resume` — continue fixing findings from the most recent audit report

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### Philosophy

This audit does real work. When conventions are wrong, rename them. When code is duplicated, extract it. When modules are dead, delete them. When architecture changed, update everything to match the new reality.

**Core goals:** Slim. Consistent. Repeatable. Good naming.

**Principles:**
- **Security first.** Never revert a security fix to resolve a quality issue. When refactoring, consider whether the change creates new attack surfaces, removes input validation, or weakens security-relevant naming. If `sanitizeInput()` exists, don't rename it to `processInput()` — the security intent in the name matters.
- **Fix forward.** If a security change introduced a naming inconsistency or compilation issue, fix it in a way that preserves the security property AND improves code quality. Both goals can be met.
- **Real refactoring, not band-aids.** Don't flag a bad name and suggest a better one — rename it and update all references. Don't flag duplication and move on — extract it. Don't flag dead code as LOW — delete it.
- **Match current architecture.** When the project has undergone a big change (new workflow, different module structure, shifted responsibilities), read `_Status.md` Active Decisions and recent git log to understand the new design intent. Update naming, module structure, exports, and conventions to match the NEW architecture. Old names that reflect old architecture are bugs, not style issues.
- **Keep what works.** Don't refactor working code that already follows conventions. Don't restructure a module that's clean and consistent just to put your stamp on it.

### Preamble

1. Detect source paths using the following fallback chain:
   - **CLAUDE.md:** Read project-level `CLAUDE.md` and parse source directories from any "Project Structure" or "Architecture" section
   - **Filesystem scan:** If no structure section, scan for `package.json`, `Cargo.toml`, `Package.swift`, `go.mod`, `pyproject.toml` — source directories = directories containing these manifests
2. Read project-level `CLAUDE.md` for architecture, naming conventions, and patterns
3. Read security and architectural context:
   a. **Security context:** Read `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/audit-context.json` if it exists. Note all files changed by `security-audit` and the security reason for each change. Read the most recent `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/security-*.md` report to understand the full security picture.
   b. **Architectural context:** Read `project_files/brain/_Status.md` (if it exists) for Active Decisions — these reveal recent architectural pivots. Scan `git log --oneline -20` for recent large changes. Understanding the current design intent prevents refactoring toward an outdated architecture.
   c. **Constraint: Security changes are sacred.** If security-audit changed a file and code-audit finds an issue in the same file caused by the security fix — fix it in a way that preserves the security remediation. Add a Decision Log note. Never revert a security fix to resolve a code quality issue. No exceptions.
4. Determine which audit categories apply based on the project type
5. Skip categories that don't apply (e.g., skip shared types for single-component CLI tools)
6. Create `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/` directory if it doesn't exist (resolve slug from `_projects.conf`)

### Audit Categories

#### 1. Shared Source of Truth

**Applies to:** Projects with multiple components sharing types.

- **Web apps:** Verify frontend + backend types come from a shared folder. Find type/interface definitions outside shared and flag duplicates.
- **Tauri apps:** Verify TypeScript interfaces match Rust struct fields across the IPC boundary. Check that invoke() parameter names match Rust function arguments.
- **Monorepos:** Check for duplicated type definitions across platform directories.
- **Skip for:** Single-component CLI tools, standalone iOS apps with no shared boundary.

#### 2. Duplicate Code Detection

**Applies to:** All projects.

- Find duplicate function signatures across source directories
- Identify repeated code patterns (3+ similar blocks)
- **Extract duplicates into shared modules.** Place extracted code in the appropriate shared directory (from CLAUDE.md `sourcePaths` or project conventions). Update all call sites to use the extracted function.
- For copy-pasted logic with minor variations: unify into a parameterized function
- When extracting, consider security: don't merge functions that have different trust boundaries (e.g., one validates input, the other doesn't)
- Generic — works for any language

#### 3. Import/Module Consistency

**Applies to:** All projects with imports.

- Check for consistent import patterns within the project
- Flag deep relative imports as candidates for aliases (if the project's build config supports them)
- Do NOT prescribe specific alias names — read from tsconfig.json, build config, etc.
- Check for unused imports (if tooling supports it)

#### 4. Naming Conventions

**Applies to:** All projects.

- Read naming conventions from CLAUDE.md (already documented per project)
- Verify codebase follows its own documented conventions
- **Fix violations directly:** Use Edit to rename files, functions, variables, types, and modules to match conventions. Trace and update ALL import paths, references, and usages. Use Bash to run typecheck/build after renaming to verify no breakage.
- If a rename would touch more than 20 files, present the change to the user via AskUserQuestion before proceeding
- Do NOT rename security-relevant identifiers to generic names (e.g., keep `validateToken`, don't rename to `processToken`)
- Do NOT hardcode React/TypeScript naming — use what CLAUDE.md specifies

#### 5. Language-Specific Lint Checks

**Applies to:** All projects, language-specific pattern-match checks only.

Detect the project's languages and check for idiomatic anti-patterns. The following are **examples**, not an exhaustive list — apply equivalent checks for whatever languages the project uses:

- **Rust:** No `unwrap()` in production code paths (use `?` or proper error handling)
- **Swift:** No force unwraps (`!`) in production code paths
- **Python:** Type hints on public functions
- **TypeScript:** No `any` types (suggest `unknown`), strict null checks
- **Go:** No unchecked errors, proper `defer` usage
- **Ruby:** No `eval()` on user input, proper exception handling

Only check patterns relevant to the project's actual languages.

#### 6. Quality Review

**Applies to:** All projects.

- Architectural issues — circular dependencies, layer violations, tight coupling
- Correctness — race conditions, off-by-one errors, null/undefined edge cases
- Type safety — unsafe casts, missing null checks, unvalidated external data
- Error handling — swallowed errors, missing error boundaries, inconsistent error patterns
- Performance — N+1 queries, unbounded loops, missing pagination, memory leaks

Assign severity directly:
- **HIGH** — significant correctness bug or architectural issue
- **MEDIUM** — quality issue or code smell with real impact
- **LOW** — style/clarity issue, minor improvement suggestion

#### 7. Dead Code Detection

**Applies to:** All projects. Runs when `--dead-code` flag is passed or as part of a full audit.

Finding IDs use the `DEA-` prefix.

**Step 1: Identify entry points**
- Detect project type and find entry points: `main` in package.json, `index.ts`/`index.js` files, app entry points, server entry points, route definitions, CLI entry points
- For multi-component projects (frontend + backend + ML), trace each component separately

**Step 2: Trace the import/require graph**
- Starting from each entry point, recursively follow all `import`/`require`/`from` statements
- Build a set of all reachable files
- Handle re-exports (`export * from`, `export { x } from`)
- Account for dynamic imports (`import()`) — flag these as "possibly used" rather than definitively dead

**Step 3: Identify unreachable files**
- Compare reachable set against all source files in the project
- Exclude non-code files that are expected (configs, assets referenced in HTML/CSS, `public/` directory contents, `package.json`, `tsconfig`, etc.)
- Exclude test files unless they import dead code
- Report unreachable files grouped by directory — if an entire directory is dead, report the directory rather than individual files

**Step 4: Identify dead exports**
- For each reachable file, find all named exports
- For each export, search the codebase for imports of that name from that file
- Flag exports that are never imported anywhere (except entry-point exports which are intentionally public)

**Severity:**
- MEDIUM for dead files/folders
- LOW for dead exports

**Each finding includes:**
- The dead file/folder/export path
- Why it's considered dead (no import chain reaches it)
- Whether it's "definitely dead" or "possibly dead" (dynamic imports exist)

**Step 5: Remove dead code** *(default mode only — skip for --dry-run)*
- Delete definitively dead files and remove dead exports
- Verify compilation after each deletion batch
- If deletion breaks something (the code wasn't actually dead — e.g., dynamically imported), restore it and mark the finding as SKIPPED with a note explaining the dynamic usage
- Report what was deleted in the findings detail

**When `--dead-code` is the only flag:** Skip all other categories, only run dead code detection. Report format is the same unified audit report.

#### 8. Root Hygiene

**Applies to:** All projects with a code repository.

Finding IDs use the `ROO-` prefix.

Repo roots accumulate configuration, runtime state, and deployment files that obscure the project's actual structure. This check identifies non-standard files at the repo root and suggests relocation.

**Step 1: Inventory root files**
- List all files (not directories) at the repo root: `ls -1p <repo_root> | grep -v /`
- Exclude dotfiles and dot-directories (`.gitignore`, `.env`, `.prettierrc`, etc.) — these are conventionally root-level

**Step 2: Filter against allowlist**

The following files are conventional at repo root and should NOT be flagged:

| Category | Files |
|----------|-------|
| Documentation | `README.md`, `README`, `CHANGELOG.md`, `CONTRIBUTING.md`, `LICENSE`, `LICENSE.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md` |
| Claude/AI | `CLAUDE.md`, `.cursorrules`, `.github/` |
| JS/TS ecosystem | `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `tsconfig.json`, `tsconfig.*.json`, `.eslintrc*`, `.prettierrc*`, `vite.config.*`, `next.config.*`, `webpack.config.*`, `rollup.config.*`, `jest.config.*`, `vitest.config.*`, `tailwind.config.*`, `postcss.config.*`, `babel.config.*`, `.babelrc` |
| Python ecosystem | `pyproject.toml`, `setup.py`, `setup.cfg`, `requirements.txt`, `requirements-*.txt`, `Pipfile`, `Pipfile.lock`, `poetry.lock`, `tox.ini`, `.flake8`, `mypy.ini`, `pytest.ini`, `conftest.py` |
| Rust ecosystem | `Cargo.toml`, `Cargo.lock`, `build.rs`, `rust-toolchain.toml` |
| Go ecosystem | `go.mod`, `go.sum` |
| Swift/Xcode | `Package.swift`, `Package.resolved` |
| Ruby ecosystem | `Gemfile`, `Gemfile.lock`, `Rakefile`, `.rubocop.yml` |
| Build/CI | `Makefile`, `CMakeLists.txt`, `Dockerfile`, `docker-compose.yml`, `docker-compose.yaml`, `Procfile`, `Justfile`, `Taskfile.yml` |
| Generic config | `*.toml`, `*.yml`, `*.yaml` files that match `<toolname>.config.*` or `.<toolname>rc` patterns |

Any file not matching the allowlist is a candidate for relocation.

**Step 3: Classify candidates**

For each non-allowlisted file, classify by likely purpose:

| Pattern | Classification | Suggested directory |
|---------|---------------|---------------------|
| `*.json` with runtime/state data (not package manifests) | Runtime state | `data/` or `state/` |
| `*.plist`, `*.service`, `*.timer` | System service / deployment | `deploy/` or `service/` |
| `install.sh`, `uninstall.sh`, `setup.sh` (not project-level setup) | Deployment scripts | `deploy/` or `scripts/` |
| `*.json` config that isn't a tool manifest | Application config | `config/` |
| Standalone scripts not related to build | Utility scripts | `scripts/` |
| Data files, fixtures, samples | Data | `data/` |

**Step 4: Report findings**

| ID | Severity | Condition | Description |
|----|----------|-----------|-------------|
| ROO-001 | warn | Non-standard file at repo root | `<filename>` at repo root — candidate for relocation to `<suggested_dir>/` |
| ROO-002 | info | 5+ non-standard files at root | Root clutter — `<N>` non-standard files at repo root suggest missing organizational structure |

**Severity:**
- WARN for individual files that clearly belong elsewhere (runtime state, deployment configs)
- INFO for borderline cases where the file might be conventional for that project type

**Step 5: Remediation** *(default mode only — skip for --dry-run)*

For each ROO-001 finding:
1. Create the suggested target directory if it doesn't exist
2. Move the file: `git mv <file> <suggested_dir>/`
3. Search codebase for references to the old path and update them
4. If the file is referenced in code with a relative path (e.g., `open("config.json")`), update those references
5. Verify the project still builds/runs after relocation

Before relocating, present the full relocation plan to the user via `AskUserQuestion` — root files often have implicit dependencies (e.g., a plist references paths, install.sh assumes CWD). Never batch-relocate without confirmation.

### Execution

1. **Analyze structure** — identify component boundaries and languages used
2. **Run all applicable categories** — sections 1–8 in order: shared types → duplicates → imports → naming → lint checks → quality → dead code → root hygiene. Collect findings with IDs.
3. **Root cause analysis** — group findings by class (not just category). For each group, ask: "What systemic gap allows this class of problem to exist?" Examples:
   - Multiple naming violations → convention not documented or enforced
   - Duplicated code across components → missing shared module or extraction pattern
   - Repeated lint anti-patterns → no linter config or CI check for this pattern
   - Dead code accumulating → no import-graph pruning in CI/CD
   - Multiple root clutter findings → no project convention for file organization documented in CLAUDE.md

   Each class gets a root cause entry (prefixed `RC-`) in the report. Individual findings link back to their root cause. A single finding can still have a root cause if the systemic gap is real.
4. **Verify findings** — Before writing any finding, confirm claims against authoritative sources. Do not infer state from indirect evidence.
   - **Git state** (tracked, ignored, committed): run `git ls-files`, `git log --name-only`, or `git status` — do not infer tracking status from filesystem presence + `.gitignore` alone.
   - **File/function existence:** use Glob or Grep to confirm before referencing in a finding.
   - **Configuration state:** read the actual config file or build output, don't assume from naming or convention.
   - A finding based on inference rather than verified evidence is a false finding. Drop it.
5. **Compile report** — use the **Write** tool to create `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/audit-YYYY-MM-DD.md` in the unified report format.
6. **Verify compilation** — after all fixes, run the project's typecheck/build command (detected from project config). If it fails, identify which fix caused the breakage, fix the regression, and re-run the build. Never leave the codebase in a broken state after an audit.
7. **Prioritize findings:** HIGH → MEDIUM → LOW
8. In default mode: present the report and ask the user what to fix (see Post-Audit)
9. In `--dry-run` mode: write the report and stop — do not fix anything

## Companion Files

- `report-template.md` — full report format, finding ID prefixes, and status values

## Output

All audit runs produce a stateful report at `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/audit-YYYY-MM-DD.md`. See `report-template.md` for the full report format.

### Post-Audit

After writing the report, present the summary table to the user and ask what to fix using AskUserQuestion:
- "Fix all issues" — fix everything, starting with highest severity
- "Fix by severity" — ask which severity level(s) to fix (HIGH, MEDIUM, LOW)
- "Fix specific IDs" — let user pick individual finding IDs
- "No fixes needed" — end the audit

When fixing issues:
1. **Fix systemic gaps first** — for each root cause (RC-), implement the principle fix (the convention, tooling, or pattern that prevents the class). This may resolve some individual findings automatically. Mark resolved findings as `FIXED`.
2. **Then fix remaining instances** — in severity order: HIGH → MEDIUM → LOW. After the systemic fix is in place, these are cleanup of existing occurrences.
3. After each fix, update the finding's status to `FIXED` in the report file
4. Update the summary table counts after each fix
5. After all fixes, append an entry to `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/audit-context.json` documenting code-audit's changes (same format as security-audit). This lets ship-check and future audit runs see the full change history.

## Resume

When the user says "continue fixing audit findings", uses `--resume`, or references an existing audit report:

1. Read the most recent `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/audit-*.md` file (legacy fallback: `.claude/reports/audit-*.md`)
2. Parse the findings table — filter to `OPEN` findings
3. Sort by severity: HIGH → MEDIUM → LOW
4. Present the remaining `OPEN` findings summary to the user
5. Ask what to fix (same options as Post-Audit)
6. Fix issues, updating each finding's status to `FIXED` in the report as you go
7. Update the summary table counts after each fix

**Status transitions:**
- `OPEN` → `FIXED` (Claude fixed it)
- `OPEN` → `SKIPPED` (user chose to skip)
- `FIXED` stays `FIXED` (never reverted)
- `SKIPPED` stays `SKIPPED` (user already decided)

## Rules

[TBD]
