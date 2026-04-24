---
name: capture
description: Use when new knowledge surfaces mid-session and needs to be written to _Status.md, _KnowledgeBase/, _Memory/, _Profile/, or _Agents/<identity>/ — also triggered after root-causing a bug, making an architectural decision, discovering a platform quirk, or hearing user-preference/feedback. Invoked directly by the user or silently by /save-session and /save-lightweight.
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Capture

Single capture primitive for the Brain vault. Routes each surfaced item to its canonical destination with consistent formatting, duplicate checks, and cap warnings. `/save-session` and `/save-lightweight` delegate all writes to this skill; users invoke it directly for mid-session captures.

## Overview

Routing is the heart of this skill. Each item type has one canonical destination, one format, one set of pre-write checks. `/capture` does not triage or clean up existing entries — `/status-audit` owns that. This skill only adds new entries or replaces targeted sections.

Three modes:
- **inline** — `/capture <type> "<text>" [flags]` — write a single item
- **sweep** — `/capture` or `/capture sweep` — interactive scan of the conversation, present candidates, route confirmed ones
- **silent** — `/capture <type> "<text>" --silent ...` — non-interactive write, used by save-session / save-lightweight

Types: `gotcha` | `decision` | `kb` | `memory` | `profile` | `oto`

## Arguments

| Flag | Applies to | Purpose |
|------|------------|---------|
| `--slug=<x>` | all | Override project resolution. Required in silent mode. |
| `--silent` | all | Suppress `AskUserQuestion`. Fail loud if required info missing. Used by caller skills. |
| `--domain=<name>` | kb | Target `_KnowledgeBase/<name>.md`. Required in silent mode. |
| `--subtype=<t>` | memory | `user` \| `feedback` \| `project` \| `reference`. Required in silent mode. |
| `--name=<s>` | memory | Snake-case slug for filename. Required in silent mode. |
| `--file=<s>` | profile | `preferences.md` \| `business.md` \| `skills.md` \| `identity.md`. Required. |
| `--section=<s>` | profile | Section heading to replace (in-place). Required in silent mode. |
| `--target=<s>` | oto | `persona.yaml` \| `standing-context.md` \| `constraints.md`. Required. |
| `--field=<s>` | oto | Field or heading to replace. Required. |
| `--date=<YYYY-MM-DD>` | gotcha, decision, kb | Override today's date (rare). |

## Process

### 0. Read Gotchas

Read `gotchas.md` in this skill's directory before proceeding.

### 1. Parse Arguments

- If no args: mode = `sweep`.
- If first arg is `sweep`: mode = `sweep`.
- If first arg is a known type: mode = `inline` (or `silent` if `--silent` flag present).
- Anything else: print usage and exit.

### 2. Resolve Slug

If `--slug=<x>` is passed, use it verbatim. Otherwise apply the save-session resolution rules **in order** — first match wins:

1. Locate Brain root and read registry:
   ```bash
   BRAIN="${BRAIN_ROOT:-}"
   if [ -z "$BRAIN" ]; then
     BRAIN=$(dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null)
   fi
   grep -v '^#' "$BRAIN/_projects.conf" | grep -v '^$'
   ```

2. Apply resolution rules:
   - **a.** CWD == `$BRAIN` → `brain`.
   - **b.** CWD under `$BRAIN/_ActiveSessions/<slug>/*` (or `_Parked`), `_Docs/<slug>/*`, `_Memory/<slug>/*`, `_DevLog/<slug>/*`, `_Workbench/<slug>/*`, `_ClaudeSettings/<slug>/*` → extract slug.
   - **c.** CWD under `~/Development/` but not `$BRAIN` → match CODE_PATH (longest prefix wins).
   - **d.** Cross-cutting Brain subdirs (`_Skills/`, `_KnowledgeBase/`, `_Profile/`, `_Agents/`, or other) → `AskUserQuestion` with all slugs (default `brain`) + "none — cancel".
   - **e.** No match → error and stop.

In silent mode, rule d is not available — if slug cannot be resolved, fail loud.

### 3. Route by Type

#### gotcha

- **Dest:** `$BRAIN/_ActiveSessions/<slug>/_Status.md` → `## Gotchas`
- **Format:** `- (YYYY-MM-DD) <text>`
- **Pre-write:** read the file; normalize first 40 chars of existing Gotchas. If fuzzy match exists:
  - Interactive: `AskUserQuestion` — skip / overwrite / append anyway.
  - Silent: skip with warning `WARN: duplicate-looking gotcha skipped — "<text>"`.
- **Write:** append as a list item under `## Gotchas`. Preserve formatting of other entries.
- **Post-write:** count list items under `## Gotchas`. If `> 10`, emit:
  ```
  ⚠ _Status.md has M Gotchas (cap 10) — run /status-audit to triage
  ```
- **Confirm:** `Captured gotcha → _ActiveSessions/<slug>/_Status.md`

#### decision

- **Dest:** `$BRAIN/_ActiveSessions/<slug>/_Status.md` → `## Active Decisions`
- **Format:** `- (YYYY-MM-DD) **<short title>:** <text>` — title is inferred from the text (first clause) in interactive mode; in silent mode the caller provides the full formatted text.
- **Pre-write:** duplicate check same as gotcha.
- **Write:** append under `## Active Decisions`.
- **Post-write:** count; if `> 25`, emit cap warning.
- **Confirm:** `Captured decision → _ActiveSessions/<slug>/_Status.md`

#### kb

- **Dest:** `$BRAIN/_KnowledgeBase/<domain>.md`
- **Domain resolution:**
  - Interactive: if `--domain` absent, `AskUserQuestion` with existing KB files + "create new: <name>".
  - Silent: `--domain` required; fail loud if absent.
- **Format:** `- <text> (as of <tool> <version>, <YYYY-MM-DD>)` — version/context required. Append under `## Gotchas` (create section if missing).
- **Pre-write (prune pass):** scan the file for entries tagged `resolved` / `superseded` / dated older than 18 months without re-verification.
  - Interactive: list them; `AskUserQuestion` — remove them.
  - Silent: list in output as prune candidates; do NOT auto-delete. Caller decides next step.
- **File creation:** if `<domain>.md` missing:
  ```markdown
  ---
  tags: [reference, <domain-lowercase>]
  ---
  # <Domain> Development Notes

  ## Gotchas
  ```
- **Confirm:** `Captured kb → _KnowledgeBase/<domain>.md (prune candidates: N)` or `(no prune candidates)`.

#### memory

- **Dest:** `$BRAIN/_Memory/<slug>/<subtype>_<name>.md`. `<slug>` defaults to resolved slug; `brain` holds cross-project entries. The directory is symlinked to `~/.claude/projects/<encoded-brain-path>/memory/` (for brain) or to code-repo Claude memory (for other projects).
- **Subtype resolution:**
  - Interactive: if `--subtype` absent, `AskUserQuestion` with four options.
  - Silent: `--subtype` required; fail loud if absent.
- **Name resolution:**
  - Interactive: if `--name` absent, infer from text (short snake_case, 2-4 words); confirm via `AskUserQuestion`.
  - Silent: `--name` required; fail loud.
- **Format:**
  ```markdown
  ---
  name: <human-readable title>
  description: <one-line description — used for relevance checks>
  type: <subtype>
  ---

  <body>
  ```
  For `feedback` and `project` subtypes, structure body: lead with the rule/fact, then `**Why:**` line, then `**How to apply:**` line. (Per global CLAUDE.md memory conventions.)
- **Pre-write:** scan `$BRAIN/_Memory/<slug>/MEMORY.md` for duplicate names. Interactive: prompt to update existing or create new. Silent: refuse with `ERROR: memory <name> exists — pass --update or rename`.
- **Post-write:** append one line to the MEMORY.md index under the matching section (`## Feedback` / `## User` / `## Project` / `## Reference`):
  ```
  - [<title>](<subtype>_<name>.md) — <one-line hook>
  ```
  If MEMORY.md is missing, skip index update and warn.
- **Confirm:** `Captured memory → _Memory/<slug>/<subtype>_<name>.md (index updated)`

#### profile

- **Dest:** `$BRAIN/_Profile/<file>.md` where `<file>` ∈ {`preferences.md`, `business.md`, `skills.md`, `identity.md`}.
- **Behavior:** edit-in-place — replace the body of the section specified by `--section`, NOT append.
- **Section resolution:**
  - Interactive: `AskUserQuestion` with existing section headings from the target file + "create new: <heading>".
  - Silent: `--section` required; fail loud if absent.
- **Pre-write:** read the file; surface current section body.
  - Interactive: present diff via `AskUserQuestion` preview; accept / edit / cancel.
  - Silent: replace the section body verbatim with the provided text.
- **Post-write:** update the `updated:` frontmatter date to today.
- **Confirm:** `Captured profile → _Profile/<file>.md (section: <heading>)`

#### oto

- **Dest:** `$BRAIN/_Agents/oto/<target>` where `<target>` ∈ {`persona.yaml`, `standing-context.md`, `constraints.md`}.
- **Behavior:** field-by-field edit. For `persona.yaml`, edit the single YAML field named by `--field`. For the markdown files, replace the section body named by `--field`.
- **MUST NOT** write to `$BRAIN/_Agents/oto/memory/` — that is oto's private scratchpad.
- **Field resolution:**
  - Interactive: `AskUserQuestion` listing available fields/headings in the target.
  - Silent: `--field` required; fail loud.
- **Create-if-missing:** if `constraints.md` does not exist (it is optional), create it with a simple heading and an empty bulleted list.
- **Pre-write:** read the file; surface current value.
  - Interactive: present diff via `AskUserQuestion` preview; accept / edit / cancel.
  - Silent: replace the field / section body with the provided text.
- **Confirm:** `Captured oto → _Agents/oto/<target> (field: <field>)`

### 4. Sweep Mode

"Since last capture/start" = **the current conversation context**. No hard boundary — scan what this agent can see in its own transcript.

#### 4a. Build candidate list

Walk the conversation. For each candidate signal, create a candidate record (type, proposed text, source excerpt).

| Signal in conversation | → candidate |
|---|---|
| "huh that's weird", "turns out X is Y", "watch out for", "I had to X to get Y" | gotcha |
| Bug root-caused (investigation → understanding → fix) | gotcha (project) or kb (platform) |
| "let's go with X over Y because Z", "decided", "we'll use…" | decision |
| Platform/framework/tool quirk (Xcode, Rust crate, CLI flag, OS behavior) | kb |
| "remember that…", "for next time…", "note for the future" | memory (user or feedback) |
| User corrected Claude's behavior | memory (feedback) |
| Cross-project workflow pattern ("you always want X") | memory (project, slug=brain) |
| User preference / identity / business revealed | profile |
| Oto behavior correction | oto |

Deduplicate against existing `_Status.md`, target KB file, and `_Memory/<slug>/MEMORY.md` index.

#### 4b. Present candidates

- If zero: `No capture candidates found since last save.` and exit.
- Otherwise, for each candidate (cap at 10 per sweep), use `AskUserQuestion` with options:
  - `write` — route per §3
  - `skip` — drop this candidate
  - `edit text` — accept a corrected body (follow-up `AskUserQuestion`)
  - `reclassify` — re-prompt with a new type (follow-up `AskUserQuestion`)

If more than 10 candidates exist, print `… and N more below the threshold — re-run /capture sweep after` and stop.

#### 4c. Summary

After all candidates processed:

```
Captured N/M candidates (G gotchas, D decisions, K kb, Mem memories, P profile, O oto)
<cap warnings if any>
<prune candidates if any>
```

### 5. Silent-Mode Failure Handling

Silent mode is invoked by `/save-session` and `/save-lightweight`. On any of:

- Missing required flag (`--slug`, `--domain`, `--subtype`, `--name`, `--file`, `--section`, `--target`, `--field`)
- Slug cannot be resolved (no `--slug` passed and rule d would prompt)
- Memory name collision without `--update`

Emit a single-line error prefixed `ERROR:` and exit non-zero. Do NOT invoke `AskUserQuestion`. Example:

```
ERROR: --domain required in silent mode
```

The caller is expected to surface this to the user and retry with the needed flag.

## Output

### Inline / silent mode (single item)

```
Captured <type> → <path> [optional metadata]
<cap warning if triggered>
```

### Sweep mode

```
Captured N/M candidates (G gotchas, D decisions, K kb, Mem memories, P profile, O oto)
<cap warnings if any>
<prune candidates if any>
```

### Silent-mode error

```
ERROR: <single-line reason>
```

## Rules

- **Route don't triage.** `/capture` only adds new entries or replaces targeted sections. Cleanup of existing entries is owned by `/status-audit`. Violating this rule means capture becomes slow and save-session becomes blocked.
- **Silent mode must not prompt.** Every `--silent` invocation is expected to complete without user interaction. A missing required flag is a fatal error, not a prompt.
- **Interactive mode confirms every item.** One `AskUserQuestion` per item. Bulk interactive writes are not supported.
- **Dates are required.** Every `_Status.md` and KB entry carries a date prefix or version/context tag. If `--date` is passed, use it; otherwise use today (`$(date +%Y-%m-%d)`).
- **Profile and oto are edit-in-place.** Never append. Always replace a specified section or field.
- **Never write to `_Agents/oto/memory/`.** That is oto's private scratchpad.
- **Cap warnings are informational, not blocking.** `/capture` always writes the entry. The warning line points the user at `/status-audit`.
- **Prune is surface-only in silent mode.** Never auto-delete KB entries when called by save-session; list prune candidates and let the user decide.
