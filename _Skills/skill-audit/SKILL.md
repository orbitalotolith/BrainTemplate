---
name: skill-audit
description: Audit all skills for template conformance, structural health, and strategic fitness. Lint, analyze, or full audit with interactive repair.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion
---

# Skill Audit

Audit every skill in `_Skills/` against the canonical skill template, check for structural issues, and evaluate strategic fitness. Three modes: full audit (self-audit → lint → analyze → report → repair → sync), lint-only (mechanical checks → report → repair → sync), and analyze-only (judgment checks → report, no repair).

## Overview

Skills drift over time — frontmatter gets stale, sections fall out of order, descriptions lose accuracy, and responsibilities blur between skills. This skill catches that drift mechanically (lint) and strategically (analyze), then offers interactive repair.

`/skill-audit` is the quality gate for `_Skills/`. Run it periodically, after editing skills, or after pulling from shared Brain.

## Arguments

| Flag | What runs | Use case |
|------|-----------|----------|
| *(none)* / `--full` | Self-audit → Lint → Analyze → Report → Repair → Sync | Periodic health check |
| `--lint` | Mechanical checks → Report → Repair → Sync | Quick check after editing or pulling skills |
| `--analyze` | Judgment checks → Report (no repair, no sync) | Strategic review |
| `--skill <name>` | Scope any mode to a single skill | Fix one skill at a time (especially useful on first run) |

`--skill` combines with any mode: `/skill-audit --lint --skill push-brain`, `/skill-audit --skill commit`.

## Companion Files

- `checks.md` — lint and analyze check catalogs with IDs, severities, and descriptions
- `report-template.md` — terminal output and report file format templates
- `suppressions.md` — "keep as-is" decisions from judgment recommendations
- `gotchas.md` — failure modes and edge cases encountered during execution

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### 1. Preamble

#### 1a. Detect Brain Root

```bash
BRAIN="${BRAIN_ROOT:-}"
if [ -z "$BRAIN" ]; then
  BRAIN=$(dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null)
fi
if [ -z "$BRAIN" ]; then
  echo "ERROR: Cannot locate Brain root. Set BRAIN_ROOT in your shell config."
  exit 1
fi
```

#### 1b. Read Check Catalog

Read `checks.md` in this skill's directory. This is the reference for all check IDs, severities, and fix actions used during lint and analyze phases.

#### 1c. Read Report Template

Read `report-template.md` in this skill's directory. This defines the output formats for terminal summaries and the report file.

#### 1d. Read Suppressions

Read `suppressions.md` in this skill's directory. Load existing suppressions into a list: `[{finding, skill, date}]`. Suppressed findings are skipped during reporting unless the skill's content has changed since the suppression date.

To detect content change: for each suppression, run `git log --since="<suppression_date>" --oneline -- "_Skills/<skill>/SKILL.md"`. If any commits exist, the suppression is stale — clear it and re-evaluate.

BHV findings cannot be suppressed.

#### 1e. Parse Mode

Determine mode from arguments:
- No args or `--full` → full mode
- `--lint` → lint mode
- `--analyze` → analyze mode
- `--skill <name>` → scope to a single skill (combines with any mode)

If `--skill` is provided, validate the name exists in the skill registry after discovery (step 2). If not found, list available skills and stop.

### 2. Discovery

Scan for all skills:

```bash
ls -d "$BRAIN/_Skills"/*/SKILL.md 2>/dev/null
```

For each `SKILL.md` found:
1. Parse YAML frontmatter: extract `name`, `description`, `user-invocable`, `disable-model-invocation`, `allowed-tools`
2. Record the directory name
3. Count total lines
4. List companion files (other `.md` files in the same directory)
5. Check for `CONTRACT.md` — if present, mark skill as critical

Also read the superpowers plugin skill list for overlap detection (FIT-001):

```bash
ls -d ~/.claude/plugins/cache/claude-plugins-official/superpowers/*/skills/*/SKILL.md 2>/dev/null
```

If multiple versions are cached, use the highest version number. For each plugin skill, extract `name` and `description` from frontmatter. These are read-only — never modified or flagged.

Build the skill registry: `[{dir_name, name, description, user_invocable, disable_model_invocation, allowed_tools, line_count, companions[], has_contract, frontmatter_raw}]`

If `--skill` was provided, filter the registry to only the named skill.

### 3. Self-Audit (full mode only)

Skip this step in `--lint` and `--analyze` modes. Skip if `--skill` targets a different skill.

Run all lint checks (FMT, SEC, NAM, GOT) and all analyze checks (FIT, INV, SCP, CMP, BHV, GOT) against `_Skills/skill-audit/SKILL.md` itself. If `CONTRACT.md` exists, include BHV-001 through BHV-004 validation.

If findings exist, present:

> ## Self-Audit
> skill-audit has N findings against its own rules:
> - [severity] ID: description
> - ...
>
> Fix these before auditing other skills? (yes / skip / abort)

- **yes** — apply auto-fixes for mechanical findings, then proceed
- **skip** — proceed with findings noted but unfixed
- **abort** — stop entirely

If no findings, report "Self-audit: clean" and proceed.

### 4. Lint Phase (full and lint modes)

Skip this step in `--analyze` mode.

For each skill in the registry (excluding `skill-audit` in full mode — already self-audited), run all mechanical checks. Reference `checks.md` for the full check catalog.

#### FMT — Frontmatter Checks

For each skill's parsed frontmatter:

1. **FMT-001:** Check all five required fields are present: `name`, `description`, `user-invocable`, `disable-model-invocation`, `allowed-tools`. Report each missing field.
2. **FMT-002:** Compare `name` field value against the directory name. Must be identical.
3. **FMT-003:** Check if `description` value is wrapped in quotes (single or double). YAML frontmatter should have unquoted values unless they contain special characters.
4. **FMT-004:** Check if `description` starts with a verb (imperative mood) or "Use when". Common valid starts: "Audit", "Create", "Run", "Use when", "Clean", "Search", etc.
5. **FMT-005:** Check field order matches canonical: `name`, `description`, `user-invocable`, `disable-model-invocation`, `allowed-tools`.
6. **FMT-006:** Parse `allowed-tools` list. For each tool, grep the SKILL.md body (below frontmatter) for the tool name. If a tool appears in `allowed-tools` but is never mentioned in the body, flag it.
7. **FMT-007:** Grep the body for known tool names (`Bash`, `Glob`, `Grep`, `Read`, `Write`, `Edit`, `AskUserQuestion`, `Agent`, `WebFetch`, `WebSearch`, `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet`, `NotebookEdit`). If a tool is referenced in the body but not in `allowed-tools`, flag it.

#### SEC — Section Structure Checks

Parse the skill body for markdown headings:

1. **SEC-001:** Required sections: `# <Title>` (H1), `## Overview`, `## Process`, `## Output`, `## Rules`. Check each exists.
2. **SEC-002:** Check order of required sections. Canonical order: `# Title` → `## Overview` → `## Arguments` (if present) → `## Process` → (optional sections) → `## Output` → `## Rules`. Required sections must appear in this relative order even if optional sections appear between them.
3. **SEC-003:** If body contains flag-like patterns (`--flag`, `-f`, arguments table) but no `## Arguments` section exists, flag it.
4. **SEC-004:** For each `## ` heading, check if it matches a canonical name (`Overview`, `Arguments`, `Process`, `Output`, `Rules`) or an optional name (`Companion Files`, `Integration`, `Resume`). Unknown names get flagged.
5. **SEC-005:** Count total lines in the file. If >200, flag as info.

#### NAM — Naming Checks

1. **NAM-001:** Compare directory name with `name` frontmatter field. Same as FMT-002 — only report once (under NAM-001, skip FMT-002 if NAM-001 fires).
2. **NAM-002:** Check if directory name contains underscores. Convention is hyphens.
3. **NAM-003:** For each companion `.md` file (not `SKILL.md`), check filename follows `lowercase-hyphenated.md` pattern. No uppercase, no underscores, no spaces.

#### GOT — Gotchas (Lint)

1. **GOT-001:** Check if `gotchas.md` exists in the skill directory. Info-level if missing.
2. **GOT-002:** If `gotchas.md` exists, grep SKILL.md for "GOTCHAS" or "gotcha". If not referenced, flag.
3. **GOT-003:** If `gotchas.md` exists, parse the date column. If any entry is older than 90 days from today, flag for review.
4. **GOT-004:** Check if `## Process` section's first subsection is `### 0. Read Gotchas`. Parse the first `###` heading after `## Process`.

Collect all findings into the findings list with their IDs, severities, skill names, and descriptions.

### 5. Analyze Phase (full and analyze modes)

Skip this step in `--lint` mode.

For each skill, read the full `SKILL.md` content. Reference `checks.md` for the analyze check catalog. These are judgment calls — every recommendation must include evidence (line counts, overlap %, specific references). Never "this feels wrong."

#### FIT — Fitness & Necessity

Read each skill fully. Cross-reference against:
- All other local skills in the registry
- All superpowers plugin skills (names and descriptions only)

1. **FIT-001 (Redundancy):** Compare each skill's description and process against every other skill (local and plugin). Evaluate using three questions: (1) **Same trigger** — would the same user prompt reasonably invoke both skills? (2) **Stolen steps** — does this skill re-implement a phase that another skill already owns as its core purpose? (3) **User confusion** — would a user be unsure which to run for the same task? If 2 or more questions are "yes", flag the overlap. Be specific: name the shared trigger or the duplicated step.
2. **FIT-002 (Decomposition):** If a skill handles 3+ distinct responsibilities that could operate independently, recommend splitting. Evidence: count the distinct phases/concerns, describe each.
3. **FIT-003 (Skill vs Agent):** If a skill is mostly imperative commands with no decision logic, branching, or user interaction, it may work better as an agent task. Evidence: count decision points vs. command steps.
4. **FIT-004 (Necessity):** If a skill wraps behavior Claude would do correctly unprompted (e.g., "read a file and summarize it"), recommend retiring. Evidence: describe what the skill adds beyond default behavior.
5. **FIT-005 (Retirement):** Grep the skill body for file paths, tool names, and pattern references. Verify each exists. If references point to files/tools/patterns that no longer exist, flag as stale.

**Standing item:** ~~`upgrade-skills` renamed to `pull-skills` (2026-04-03).~~ Resolved.

#### INV — Invocability

For each skill, evaluate whether its invocability settings match its nature:

1. **INV-001:** If `disable-model-invocation: true` but the description contains trigger phrases ("Use when", "TRIGGER when", "Use this skill when"), the skill is written to be detected by agents. Consider `disable-model-invocation: false`.
2. **INV-002:** If `disable-model-invocation: false` but the skill is destructive (deletes files, modifies configs, pushes to remote), slow (multi-phase audit), or requires user intent (financial, irreversible), consider `disable-model-invocation: true`.
3. **INV-003:** If `user-invocable: false` but the skill has a clear standalone use case (could be triggered by `/name`), consider `user-invocable: true`.
4. **INV-004:** If `user-invocable: true` but the skill is only called by other skills (internal helper), consider `user-invocable: false`.

#### SCP — Scope & Generalization

1. **SCP-001 (Over-generalized):** If a skill handles multiple project types but inspection of `_Skills/` usage shows it only runs on one type, flag.
2. **SCP-002 (Under-generalized):** Grep the skill body for hardcoded paths, project names, or Brain-specific references that should be dynamic. Evidence: the specific hardcoded strings.
3. **SCP-003 (Hardcoded living data):** Compare the skill's rules/checks against current content of `$BRAIN/_HowThisWorks.md`, `$BRAIN/key-to-dev.md`, and `$BRAIN/_projects.conf`. If the skill duplicates rules from these files instead of reading them at runtime, flag. The `folder-audit` step 0b pattern (read living doc at runtime) is the model.

#### CMP — Companion File Opportunities

1. **CMP-001:** Scan skill body for formatted output blocks (fenced code blocks, blockquote templates) longer than 20 lines. Recommend extracting to a companion file.
2. **CMP-002:** Scan for lookup tables or catalogs (markdown tables >10 rows). Recommend extracting if maintainable separately.
3. **CMP-003:** List `.md` files in the skill directory. Grep SKILL.md for references to each. If a companion exists but isn't referenced, flag.

#### BHV — Behavioral Contract

Two modes: **validation** (skill has `CONTRACT.md`) and **recommendation** (skill lacks one but should have it).

##### BHV-005: Should this skill have a contract?

For each skill **without** `CONTRACT.md`, evaluate against these criteria. A skill warrants a contract if it meets **2 or more**:

1. **Stateful** — modifies files, git state, vault structure, or external systems (not read-only)
2. **Foundational** — other skills depend on it, or it's part of the core daily workflow (`start-session`, `save-session`, `commit`, etc.)
3. **Multi-step with user interaction** — has 4+ process steps with decision points or user confirmations
4. **Trust boundary** — crosses a trust boundary (pushes to remote, syncs across machines, writes to shared resources)
5. **Gotcha-prone** — has 3+ entries in `gotchas.md`, suggesting behavioral drift is a real risk

If 2+ criteria met → BHV-005 recommendation. List which criteria matched and why.

##### BHV-001 through BHV-004: Contract validation

Only runs for skills that have a `CONTRACT.md` companion file. If no `CONTRACT.md`, skip.

For each skill with `CONTRACT.md`:

1. Read `CONTRACT.md` — parse the invariant table into a list: `[{id, invariant_text}]`
2. For each invariant:
   a. **Parse the claim** — what behavior is required, under what conditions
   b. **Search `SKILL.md`** for process steps that implement this behavior. Look for keywords, action verbs, and tool references that correspond to the invariant.
   c. **If no corresponding step found** → BHV-001 (missing invariant). Quote the invariant and note which process sections were searched.
   d. **If found, evaluate strength:**
      - Does the step fully satisfy the invariant, or are there conditional paths that skip it? → BHV-002 (weakened)
      - Does the invariant say "read X at runtime" but the skill hardcodes the content? → BHV-003 (hardcoded override)
      - Does the invariant say "must ask/confirm" but a code path acts without interaction? → BHV-004 (silent action)
   e. **Report with evidence** — quote the invariant, the corresponding process step (or absence), and the specific gap

BHV-001 through BHV-004 are always errors. Never auto-fixed — always presented for user decision with the exact invariant and process step quoted side by side.

#### GOT — Gotchas (Analyze)

If `gotchas.md` exists for a skill:

1. **GOT-005:** Group entries by root cause. If same root cause appears 2+ times, the skill process has a structural gap.
2. **GOT-006:** For each gotcha with a mitigation, grep SKILL.md for related keywords. If the mitigation hasn't been absorbed into the skill, recommend the specific edit. After absorption is applied and verified, mark the gotcha entry `[absorbed]` in gotchas.md.
3. **GOT-007:** For each gotcha that describes a step producing wrong results, check if the referenced step has been updated since the gotcha date.
4. **GOT-008:** Count gotchas per SKILL.md section (by matching section names in gotcha descriptions). If 3+ gotchas cluster around one section, feed into FIT-002 decomposition.

Collect all recommendations into the findings list. Each recommendation includes the evidence that led to it.

### 6. Report

Reference `report-template.md` for output formats.

#### Write Report File

Create `$BRAIN_ROOT/_Docs/<slug>/Reports/skill-audit-YYYY-MM-DD.md` using the report file template:

1. Ensure `$BRAIN_ROOT/_Docs/<slug>/Reports/` directory exists (create if not, resolve slug from `_projects.conf`)
3. Write the report with all findings and recommendations
4. Set status for each finding: `OPEN` (unfixed), `SUPPRESSED` (in suppressions.md)

#### Present Terminal Summary

Use the full summary template (table format) for `--full` mode.
Use the compact template for `--lint` mode.
For `--analyze` mode, use the full summary but only show FIT/INV/SCP/CMP/BHV/GOT columns.

If zero findings across all checks, report that all skills are clean and stop. Do not manufacture findings.

### 7. Interactive Repair (full and lint modes)

Skip this step in `--analyze` mode. Read-only until user approves.

Use AskUserQuestion for repair confirmations and menu selections (repair menu, contract violation walk, judgment walk).

Present the repair menu from `report-template.md`:
- **Fix all mechanical** — auto-fix all FMT/SEC/NAM/GOT findings
- **Fix errors only** — auto-fix mechanical errors, skip warnings
- **Review violations + recommendations** — walk BHV violations first, then judgment findings (full mode only)
- **Fix all + review** — auto-fix mechanical, then walk violations and recommendations (full mode only)
- **Report only** — stop here

#### Mechanical Auto-Fixes

Reference the auto-fix table in `checks.md`. Execute fixes in this order:

1. **FMT fixes first** — frontmatter is the foundation
   - FMT-001: Add missing fields with defaults (`user-invocable: true`, `disable-model-invocation: true`, `allowed-tools: Read`). Flag added fields for review.
   - FMT-002: Update `name` to match directory name
   - FMT-003: Remove surrounding quotes from description
   - FMT-005: Reorder fields to canonical order, preserving values
2. **SEC fixes second** — section structure
   - SEC-001: Insert stub section with `[TBD]` content at the correct position per canonical order
   - SEC-002: Reorder sections, preserving all content within each section. Verify: non-whitespace line count before and after must be equal.
3. **NAM fixes third** — naming
   - NAM-001: Rename directory to match `name` field. Update all references.
   - NAM-002: Replace underscores with hyphens in directory name. Update all references.
4. **GOT fixes last** — gotchas integration
   - GOT-004: Insert `### 0. Read Gotchas` step as first subsection under `## Process`

Use the Edit tool to apply each change. After each fix, re-read the modified file to verify the change landed correctly before proceeding to the next fix.

#### Contract Violation Walk (BHV)

BHV findings are errors that cannot be auto-fixed. Present them before judgment recommendations because they represent broken promises on critical skills.

For each BHV finding, present using the contract violation walk format from `report-template.md`:
- The contract invariant (quoted from CONTRACT.md)
- The corresponding SKILL.md process step (or absence)
- The specific gap

User choices:
- **Fix SKILL.md** — edit the process step to satisfy the invariant
- **Update CONTRACT.md** — the invariant is too strict; user adjusts it
- **Defer** — skip without fixing; will appear again next run

BHV-001 through BHV-004 cannot be suppressed. A contract violation must be resolved by fixing the skill or updating the contract.

#### Contract Creation Walk (BHV-005)

When BHV-005 recommends a contract for a skill, walk through creation with the user:

1. Present the criteria that matched:
   ```
   [BHV-005] <skill> — contract recommended
     Criteria met:
     - Stateful: <evidence>
     - Foundational: <evidence>
     ...

     → Create CONTRACT.md together
     → Skip (no contract needed)
     → Defer
   ```

2. If user chooses to create, draft invariants collaboratively:
   a. Read the skill's `SKILL.md` fully
   b. Identify the behaviors that **must not drift** — the promises the skill makes
   c. For each candidate invariant, propose it and ask the user to confirm, edit, or reject
   d. Focus on behaviors where silent failure would cause harm (data loss, stale context, broken sync)
   e. Keep invariants concrete and testable — "must read X before Y", not "should be careful"

3. Write `CONTRACT.md` in the skill directory with this format:
   ```markdown
   # Contract — <skill-name>

   Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
   Violations are errors — the skill or the contract must be updated to resolve them.

   | ID | Invariant |
   |----|-----------|
   | 1  | <invariant text> |
   | 2  | <invariant text> |
   ```

4. After writing, immediately run BHV-001 through BHV-004 against the new contract to verify the skill already satisfies all invariants. Fix any gaps before proceeding.

#### Judgment Recommendation Walk

For each recommendation (full mode only), present using the walk format from `report-template.md`. User choices:

- **Action option** (e.g., "Split into two skills", "Rename to X") — apply the change
- **Keep as-is** — record in `suppressions.md` with the user's reasoning and today's date
- **Defer** — skip without suppressing; will appear again next run

### 8. Post-Repair Sync (full and lint modes, after repairs)

Skip if no changes were made. Skip in `--analyze` mode.

#### Sync Process

1. Diff pre-audit and post-audit state of `_Skills/` — which skills were renamed, modified, added, or retired
2. Read `$BRAIN/key-to-dev.md` — find the skill reference section
3. Rebuild skill entries from `_Skills/*/SKILL.md` frontmatter (name + description)
4. Read `$BRAIN/_HowThisWorks.md` — grep for any old skill names that were renamed
5. Present the proposed diffs to the user before writing:

> Post-repair sync:
>   key-to-dev.md: updated N skill entries, removed N, added N
>   _HowThisWorks.md: renamed X → Y (N references)
>
> Apply? (yes / skip)

6. On "yes" — write changes to both files
7. On "skip" — leave files as-is, note in report

After sync, remind:
> Note: skill descriptions changed — restart Claude Code to update session reminder text.

### 9. Gotcha Review (all modes)

Always runs, even if no repairs were made. Present:

> Did anything unexpected happen this run? (log / skip)

If "log": open `gotchas.md` in the skill's directory and guide the user to add an entry:

```
| <today's date> | <what happened> | <root cause> | <mitigation> |
```

Keep entries terse — one line per incident. If the mitigation has already been absorbed into the skill process, mark the entry `[absorbed]`.

If "skip": proceed without logging.

## Output

The skill produces:

1. **Terminal summary** — printed at the end of every run (format varies by mode, see `report-template.md`)
2. **Report file** — `$BRAIN_ROOT/_Docs/<slug>/Reports/skill-audit-YYYY-MM-DD.md` (written in full and lint modes)
3. **Suppressions updates** — `suppressions.md` updated with "keep as-is" decisions (full mode only)
4. **Repaired skill files** — modified `SKILL.md` files and renamed directories (full and lint modes, after user approval)
5. **Synced reference files** — `key-to-dev.md` and `_HowThisWorks.md` updated to reflect changes (full and lint modes, after user approval)

## Rules

1. **Self-audit runs first in full mode.** No exceptions.
2. **Mechanical checks are deterministic.** Same input = same findings.
3. **Judgment checks explain their reasoning.** Every recommendation includes evidence (line counts, overlap %, specific paths). Never "this feels wrong."
4. **Never auto-fix judgment findings.** Always present for user decision.
5. **Suppressions are durable but not permanent.** Content change clears the suppression. BHV-001 through BHV-004 cannot be suppressed. BHV-005 can be suppressed (it's a recommendation).
6. **Read-only until user approves.** Discovery, lint, and analyze never modify files.
7. **Post-repair sync is mandatory.** If any skill changed, `key-to-dev.md` and `_HowThisWorks.md` must be updated.
8. **Living documents are authoritative.** Check SCP-003 against current file state, not hardcoded expectations.
9. **Don't manufacture findings.** If all skills are clean, say so and stop.
10. **Canonical template applies to `_Skills/` only.** Superpowers plugin skills are read for cross-reference but never modified or flagged.
11. **NAM-001 and FMT-002 are the same check.** Only report once, under NAM-001.
12. **Target freshness rule.** After modifying any file, re-read it before proposing further changes to the same file.
13. **Contract violations are errors.** BHV-001 through BHV-004 are always errors, never warnings, never auto-fixed, never suppressed. They must be resolved by fixing the skill or updating the contract. BHV-005 (missing contract) is a recommendation — walked interactively, suppressible.
