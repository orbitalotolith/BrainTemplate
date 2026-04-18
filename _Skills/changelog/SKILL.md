---
name: changelog
description: Generate changelog from git history for releases
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# Changelog

Generate a changelog from git history. Useful for releases and version documentation. See CLAUDE.md "Workflow Conventions" for standard paths.

## Overview

[TBD]

## Arguments

- `--version <version>` — set the version header (default: "Unreleased")
- `--since <tag-or-date>` — start of range
- `--until <tag-or-date>` — end of range (default: HEAD)
- `--preview` — display inline without writing to file

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### 1. Determine Range

- **Default:** Last tag to HEAD
  - `git describe --tags --abbrev=0` to find the last tag
  - If no tags exist, use all commits
- **User-specified:** Accept a range argument (e.g., `v1.0.0..HEAD`, `v1.0.0..v1.1.0`)
- **Since date:** Accept `--since YYYY-MM-DD`

### 2. Parse Commits

Read commits in the determined range:
```
git log [range] --pretty=format:"%H|%s|%an|%ad" --date=short
```

Categorize by Conventional Commits prefix:
- `feat:` → **Added**
- `fix:` → **Fixed**
- `refactor:` → **Changed**
- `docs:` → **Documentation**
- `test:` → **Tests**
- `chore:` → **Maintenance**
- `style:` → **Style**
- No prefix or other → **Other**

Extract scope if present: `feat(auth): Add login` → scope is `auth`.

### 3. Format Output

```markdown
## [version] - YYYY-MM-DD

### Added
- Description of new feature (abc1234)
- Another feature (def5678)

### Fixed
- Description of bug fix (ghi9012)

### Changed
- Description of refactor (jkl3456)

### Documentation
- Updated README (mno7890)

### Maintenance
- Updated dependencies (pqr1234)
```

### 5. Write or Display

- **Write to file:** Append to top of `CHANGELOG.md` (after any existing header). Create the file if it doesn't exist.
- **Display inline:** If user asks for preview, show in chat instead of writing.

Use AskUserQuestion: "Write to CHANGELOG.md, or display here?" Use Bash for all git commands.

## Output

[TBD]

## Rules

- Commit descriptions should be human-readable — clean up if needed
- Deduplicate: if multiple commits describe the same change, combine them
- Skip merge commits and fixup commits
- Include commit short hash for reference
- Group by category, then sort by date within each category
