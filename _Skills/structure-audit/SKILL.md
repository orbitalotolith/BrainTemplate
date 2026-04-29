---
name: structure-audit
description: Audit each code repo's internal layout against Universal Project Structure conventions — flags non-standard directories, platform targets that belong under clients/, and frameworks that belong in core/
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Glob, Grep, Read, Edit, AskUserQuestion
---

# Structure Audit

Validates that each code repo's internal directory layout follows the Universal Project Structure defined in `_HowThisWorks.md`. Detects non-standard top-level directories, platform-specific targets that should be under `clients/`, and shared frameworks that belong in `core/`.

`/folder-audit` checks Brain integration (symlinks, registry, ActiveSessions). `/structure-audit` checks what's inside each code repo. Run after adding new directories to a project or when repo layout feels disorganized.

## Overview

Code repos accumulate directories organically — Xcode targets, platform variants, experiments. This skill catches layout drift by comparing each repo's top-level structure against the canonical Universal Project Structure from `_HowThisWorks.md`. It understands project types (Xcode, Cargo, npm) and provides context-aware suggestions for reorganization.

## Arguments

| Flag | What runs | Use case |
|------|-----------|----------|
| *(none)* | All projects in `_projects.conf` | Full audit |
| `--project <slug>` | Single project | Quick check after restructuring |

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.

### 1. Preamble

#### 1a. Detect Brain Root

Use the **Bash** tool to run:

```bash
BRAIN="${BRAIN_ROOT:-}"
if [ -z "$BRAIN" ]; then
  BRAIN=$(dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null)
fi
```

#### 1b. Read Structural Reference

Read `$BRAIN/_HowThisWorks.md` — specifically the **Universal Project Structure** section. This defines the canonical layout. Do not hardcode structural rules — read them at runtime.

#### 1c. Read Project Registry

Use the **Grep** tool to read the project registry:

```bash
grep -v '^#' "$BRAIN/_projects.conf" | grep -v '^$'
```

Parse `SLUG|CATEGORY|CODE_PATH` triples. If `--project` was given, filter to that slug.

### 2. Discovery

For each project with a code path:

#### 2a. Verify Code Repo Exists

```bash
repo="$HOME/Development/$CODE_PATH"
[ -d "$repo/.git" ] || skip  # not cloned on this machine
```

Skip projects whose code repo isn't cloned — record as "skipped" for the execution gate.

#### 2b. Detect Project Type

Scan the code repo root for build manifests:

| Manifest | Project type |
|----------|-------------|
| `.xcodeproj/` or `project.yml` | Xcode/Swift |
| `Cargo.toml` | Rust |
| `package.json` | Node.js |
| `pyproject.toml` or `setup.py` | Python |
| `go.mod` | Go |
| `Package.swift` | Swift Package Manager |

A project may have multiple types (e.g., Rust + Xcode for FFI projects).

#### 2c. Xcode Target Discovery

When an Xcode project is detected:

1. **If `project.yml` exists** (xcodegen): parse the `targets:` section to extract each target's `name`, `platform` field, and `sources` paths. Build a target map: `{<directory_name>: <platform>}`.

   Example from a `project.yml`:
   ```yaml
   targets:
     <ProjectIOS>:
       platform: iOS
       sources:
         - <ProjectIOS>
     <ProjectMac>:
       platform: macOS
       sources:
         - <ProjectMac>
   ```
   Produces target map: `{<ProjectIOS>: iOS, <ProjectMac>: macOS}`

2. **If `.xcodeproj/` exists without `project.yml`**: scan `*.xcodeproj/project.pbxproj` for `buildSettings` containing `SDKROOT` or `SUPPORTED_PLATFORMS` to map targets to platforms. This is less reliable — flag confidence as "inferred" vs "confirmed" for `project.yml`.

3. Also check for `packages:` in `project.yml` — these reference local Swift packages (e.g., `<ProjectKit>`) that should map to `core/` or `clients/shared/`.

#### 2d. List Top-Level Directories

Use the **Glob** tool to list top-level directories, or use the **Bash** tool to run:

```bash
ls -d "$repo"/*/ 2>/dev/null | xargs -I{} basename {}
```

Exclude files — only directories.

### 3. Validation

For each code repo, run UPS checks against the top-level directory list. Every check category below MUST execute for every project — do not skip or shortcut.

#### 3a. Filter Known-Acceptable Directories

Remove directories from the list that match the known-acceptable set:

| Category | Directories |
|----------|-------------|
| Source structure | `core/`, `clients/`, `test/`, `tests/`, `config/` |
| System/tooling | `project_files/`, `.git/`, `.github/`, `.claude/`, `.worktrees/`, `.vscode/`, `.idea/` |
| Build artifacts | `node_modules/`, `venv/`, `.venv/`, `build/`, `dist/`, `target/`, `.next/`, `__pycache__/`, `.build/` |
| Library conventions | `examples/` |

**Explicitly NOT acceptable at repo root** (see UPS-004 and UPS-005 for canonical targets):

- `docs/` — split: human-authored content (specs, designs, proposals, research drafts) belongs in `project_files/brain/_Workbench/`; AI execution plans and audit reports belong in `project_files/brain/_AgentTasks/` (UPS-004)
- `src/`, `lib/` — UPS: *"Source code goes in `core/` and/or `clients/` — never loose at root"*
- `scripts/`, `tools/` — dev scripts live in `project_files/tools/`
- `assets/` — source/design assets go in `project_files/assets/`; shipped assets go inside a client dir
- `public/`, `static/` — web/frontend concepts belong inside `clients/<platform>/`
- `vendor/` — vendored deps live under `core/` or the relevant client
- `resources/` — belongs inside `core/` or `clients/<platform>/`
- `fixtures/` — test fixtures live under `tests/fixtures/`
- `migrations/` — DB migrations belong under `core/`

Anything remaining is a candidate for UPS-001, UPS-002, or UPS-003.

#### 3b. UPS-001 — Non-Standard Top-Level Directory

Each remaining directory that does NOT match any keyword or Xcode target gets UPS-001 (warn):
```
[warn] UPS-001: Non-standard top-level directory `<name>/` — review whether it belongs under `core/`, `clients/`, or elsewhere
```

#### 3c. UPS-002 — Platform/Framework Directory at Root

Upgrade to UPS-002 (error) if the directory name contains any of these keywords (case-insensitive substring match):

**Platform keywords:** `web`, `ios`, `macos`, `mac`, `android`, `desktop`, `mobile`, `watch`, `tv`

**Framework/role keywords:** `kit`, `shared`, `common`, `proto`, `server`, `api`, `backend`, `frontend`, `relay`, `agent`

**Release/build keywords:** `release`, `deploy`, `production`, `staging`

**Suggested targets:**

| Keyword in name | Suggested location |
|-----------------|-------------------|
| `web`, `frontend` | `clients/web/` |
| `ios` | `clients/ios/` |
| `macos`, `mac` | `clients/macos/` |
| `android` | `clients/android/` |
| `desktop` | `clients/desktop/` |
| `mobile` | `clients/mobile/` |
| `watch` | `clients/watch/` |
| `tv` | `clients/tv/` |
| `kit`, `shared`, `common` | `core/` or `clients/shared/` |
| `server`, `api`, `backend` | `core/` |
| `proto` | `core/proto/` |
| `agent`, `relay` | `core/` or `clients/<platform>/` (use Xcode target map if available) |
| `release`, `deploy`, `production`, `staging` | Should not exist as top-level directories |

**Combined patterns:** If a directory name contains both a platform keyword and another keyword (e.g., `dimension-studio-web-release`), use the platform keyword to determine the target.

**Single-platform nuance:** If a project has only one platform and one source directory at root (e.g., just `backend/`), the repair may be "rename to `core/`" rather than "move under `clients/`". Use judgment based on the project's CLAUDE.md and structure.

**Context check — before reporting UPS-002 as `[error]`:**

A keyword match alone is low-confidence. Before classifying as `[error]`, check for signals that the directory is a legitimate top-level category. If ANY of the following are true, downgrade to `[review]`:

1. **Domain overlap:** The matched keyword appears in the project slug (from `_projects.conf`) or the project's manifest `name`/`description` field. If the project IS about agents, `agents/` is the domain — not a misplaced directory.
2. **Independent packages:** The flagged directory contains subdirectories with their own build manifests (`pyproject.toml`, `package.json`, `Cargo.toml`, `Package.swift`). This indicates a top-level category of deployable components (like `clients/`), not misplaced code.
3. **Naming collision:** `core/<flagged-dir-name>/` already exists in the repo. Moving would conflate infrastructure with implementations.

When downgrading, include the reasoning:
```
[review] UPS-002: `agents/` matches "agent" keyword, but: domain overlap with project slug "<your-project-slug>", contains independent packages (2 pyproject.toml), core/agents/ already exists → likely intentional
```

Only findings that pass the context check without any signals remain `[error]`.

#### 3c-bis. UPS-004 — Docs Directory at Repo Root

Documentation does not live at the code repo root — it lives in Brain and is accessed via two symlinks: `project_files/brain/_Workbench/` for human-authored content (specs, design docs, proposals, research drafts) and `project_files/brain/_AgentTasks/` for AI execution plans and audit reports. If the top-level directory list contains a `docs/` (case-insensitive), emit UPS-004 (error):

```
[error] UPS-004: `docs/` at repo root — documentation belongs in Brain. Move human content (specs, designs, proposals) into `project_files/brain/_Workbench/` (symlink resolves to `<Brain>/_Workbench/<slug>/`); move AI execution plans and audit reports into `project_files/brain/_AgentTasks/` (symlink resolves to `<Brain>/_AgentTasks/<slug>/`). Then delete the repo-root `docs/`.
```

Rationale (from `_HowThisWorks.md` and `_Memory/brain/feedback_no_spec_docs.md`): `_Workbench/` holds human-authored content visible alongside other vault notes in Obsidian; `_AgentTasks/` holds AI execution plans and audit reports kept separate so neither material drowns the other. There is no separate `docs/` at project root. Public-facing docs that *must* ship with the code (e.g., GitHub Pages site, API reference published from the repo) are the only legitimate exception — flag as `[review]` instead of `[error]` if a `docs/` contains a recognized publishing config (`mkdocs.yml`, `docusaurus.config.js`, `_config.yml` for Jekyll, `book.toml` for mdBook).

#### 3c-ter. UPS-005 — Misplaced Conventional Directory

Certain directory names are common in the wild but violate UPS' rule that *"Source code goes in `core/` and/or `clients/` — never loose at root"*. If a top-level directory name matches (exact, case-insensitive), emit UPS-005 (error) with the specific target from the table:

| Directory | Canonical target per UPS |
|-----------|--------------------------|
| `src/` | `core/` (rename for single-platform projects) or move under `core/` / `clients/<platform>/src/` |
| `lib/` | `core/` |
| `scripts/` | `project_files/tools/` |
| `tools/` | `project_files/tools/` |
| `assets/` | `project_files/assets/` (source) or `clients/<platform>/public/` (shipped) |
| `public/` | `clients/<platform>/public/` |
| `static/` | `clients/<platform>/static/` |
| `vendor/` | Under `core/` or the relevant client |
| `resources/` | Under `core/` or `clients/<platform>/` |
| `fixtures/` | `test/fixtures/` (or `tests/fixtures/`) |
| `migrations/` | `core/migrations/` |

Message format:
```
[error] UPS-005: `<name>/` at repo root → move to `<target>` per UPS
```

**Context check — downgrade to `[review]` when:**

1. **Single-file marker:** `assets/` containing only an app icon referenced by build configs (`tauri.conf.json`, `Info.plist`, `Contents.json`) — moving requires updating the build configs.
2. **Single-platform backend-only:** A project with no `clients/` and one source directory named `src/` may be a bare Rust/Python/Node package where `src/` is the build-tool default. Suggest `[review]` with note: "Consider renaming to `core/` per UPS, or leave if this is a single-crate/package library."
3. **Published examples:** `examples/` is acceptable for library projects and listed in known-acceptable.

When downgrading, include reasoning in the message.

#### 3d. UPS-003 — Xcode-Informed Suggestion

When Xcode target discovery (step 2c) produced a target map, upgrade any UPS-001 or UPS-002 finding that matches a known target to UPS-003 (error, high confidence):

For each flagged directory that matches a known Xcode target:
1. Look up the target's platform from the target map
2. Map platform to conventional directory:
   - `iOS` → `clients/ios/`
   - `macOS` → `clients/macos/`
   - `watchOS` → `clients/watch/`
   - `tvOS` → `clients/tv/`
3. Replace the generic suggestion with a specific one:
   ```
   [error] UPS-003: `<ProjectMac>/` is a macOS target (project.yml) → move to `clients/macos/`
   ```

For local Swift packages found in `project.yml` `packages:` section, suggest `core/` or `clients/shared/`:
```
[error] UPS-003: `<ProjectKit>/` is a local Swift package (project.yml) → move to `core/` or `clients/shared/`
```

If the target platform can't be determined, fall back to UPS-002 or UPS-001.

UPS-003 is always an error — Xcode target mapping provides higher confidence than keyword matching.

#### 3e. Execution Gate

After running all checks, print a coverage checklist:

```
Structure audit checked N projects:
  ✓ projecta (Xcode/Swift + Rust) — 8 findings
  ✓ projectb (Rust) — 0 findings
  ✓ projectc (Xcode/Swift) — 2 findings
  ✗ projectd — skipped (repo not cloned)
```

This prevents silent skipping. Every project in `_projects.conf` must appear — either checked or explicitly skipped with a reason.

### 4. Report

Present findings grouped by project, with project type shown:

```
## Structure Audit Report

### <ProjectA> (<Category>/<ProjectA>) — Xcode/Swift + Rust
- [error] UPS-003: `<ProjectA>/` is an iOS target (project.yml) → move to `clients/ios/`
- [error] UPS-003: `<ProjectA>Mac/` is a macOS target (project.yml) → move to `clients/macos/`
- [error] UPS-003: `<ProjectA>Kit/` is a local Swift package (project.yml) → move to `core/` or `clients/shared/`
- [error] UPS-002: `<projecta>-core/` contains "core" keyword → rename to `core/`
- [error] UPS-002: `<projecta>-proto/` contains "proto" keyword → move to `core/proto/`
- [error] UPS-002: `desktop-agent/` contains "desktop" + "agent" → move to `clients/desktop/`
- [warn] UPS-001: `DebuggingAppTests/` — review placement (tests/?)
- [warn] UPS-001: `infrastructure/` — review placement

### <ProjectB> (<Category>/<ProjectB>) — Python
- [review] UPS-002: `agents/` matches "agent" keyword, but: domain overlap with "<projectb>", contains independent packages, core/agents/ already exists → likely intentional

### Summary
Errors: 6 | Reviews: 1 | Warnings: 2 | Projects checked: N | Projects skipped: N
```

`[review]` findings are reported but NOT included in repair options — they require manual judgment, not automated moves.

If zero findings across all projects, report that all layouts are clean and stop. Do not manufacture findings.

### 5. Interactive Repair

Use **AskUserQuestion** to present repair options:

- **Fix all** — apply all moves with per-item confirmation
- **Fix by project** — choose which projects to repair
- **Report only** — stop here, no changes

For each approved move:

1. Show source and destination clearly
2. Create destination directory if needed: `mkdir -p <dest>`
3. Move via `git mv <old> <new>` (preserves git history)
4. Search for references to update:
   ```bash
   grep -rn "<old-name>" --include="*.md" --include="*.json" --include="*.yml" --include="*.yaml" --include="*.toml" --include="*.swift" --include="*.rs" --include="*.ts" --include="*.js" --include="*.sh" .
   ```
5. Present each reference for confirmation before updating. Use the **Edit** tool to update references.
6. For Xcode projects: warn that `project.yml` / `.xcodeproj` will need target path updates after all moves

**Per-item confirmation required.** Never batch-move directories.

After all moves for an Xcode project, remind:
> Note: Update `project.yml` target source paths to reflect the new layout, then run `xcodegen generate`.

## Output

1. **Execution gate** — checklist confirming which projects were checked and which were skipped
2. **Terminal report** — findings grouped by project with project type context
3. **Repaired files** — moved directories with updated references (after user approval only)

## Rules

1. **Read-only until user approves.** Phases 1-4 never modify files.
2. **Read `_HowThisWorks.md` at runtime.** Do not hardcode the Universal Project Structure layout or known-acceptable list — read them from the living document.
3. **Per-item confirmation for all moves.** Never batch-move directories.
4. **Execution gate is mandatory.** Always print the coverage checklist before reporting findings. Every project in `_projects.conf` must appear.
5. **Xcode target map is advisory.** If `project.yml` parsing fails or `.xcodeproj` analysis is ambiguous, fall back to keyword matching (UPS-002). Never block on parse failures.
6. **Don't manufacture findings.** If layout is clean, say so.
7. **After moves, update references.** Search all relevant file types for old directory names.
8. **Warn about build system updates.** Xcode projects need `project.yml` / `.xcodeproj` path updates after moves — remind the user but do not auto-edit build configuration files.
9. **Single-platform projects may skip `clients/`.** If a project has exactly one platform target and no multi-client architecture, `core/` alone is acceptable — do not force a `clients/` wrapper.
10. **This skill does not check Brain integration.** Symlinks, registry entries, ActiveSessions, memory directories — those are `/folder-audit`'s responsibility.
