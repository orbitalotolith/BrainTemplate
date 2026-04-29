---
name: vault-search
description: Search across DevLog history and KnowledgeBase entries for past decisions, problems, and context. Use when you need historical context about a project, past debugging sessions, architectural decisions, or recurring issues.
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Grep, Read, AskUserQuestion
---

# Vault Search

Search across all session history (DevLog files) and KnowledgeBase entries for a given query. Use this when you need to recall past decisions, diagnose recurring problems, or find when something was last worked on.

## Overview

[TBD]

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### 1. Get Search Query

If the user provided a search term as an argument, use it. Otherwise use AskUserQuestion to ask what they're looking for.

### 2. Search

First use the **Bash** tool to detect Brain root:

```bash
BRAIN="${BRAIN_ROOT:-}"
if [ -z "$BRAIN" ]; then
  BRAIN=$(dirname "$(find "$HOME/Development" -maxdepth 2 -name '_ActiveSessions' -type d 2>/dev/null | head -1)" 2>/dev/null)
fi
if [ -z "$BRAIN" ]; then
  echo "ERROR: Cannot locate Brain root. Run _setup.sh or set BRAIN_ROOT in your shell config."
  exit 1
fi
```

Use Grep to search across these locations (case-insensitive, with 2 lines of context):

- `$BRAIN/_DevLog/` — Brain's own session history and project DevLogs (per-slug subdirectories)
- `$BRAIN/_Workbench/` — project workbench files (per-slug real directories)
- `$BRAIN/_ActiveSessions/` — session files and _Status.md files (per-slug subdirectories)
- `$BRAIN/_KnowledgeBase/` — cross-project technical knowledge

### 3. Present Results

Group results by source type:

```
## DevLog Matches
- **2026-03-21** (<ProjectName>): "matched line with context..."
- **2026-03-16** (Brain): "matched line with context..."

## KnowledgeBase Matches
- **BLE.md**: "matched line with context..."

## ActiveSessions Matches
- **_ActiveSessions/<slug>/_Status.md**: "matched line with context..."
```

- Show at most 20 results per category
- Include the file path (relative to Brain root) and surrounding context
- For DevLog matches, extract the date from the filename

### 4. Offer Follow-Up

If results are found, offer to read the full file for any match the user wants to explore further.

If no results, suggest broadening the search terms or trying related keywords.

## Output

[TBD]

## Rules

- Read-only -- never modify any files
- Case-insensitive search by default
- Support regex patterns in the query
- Keep output scannable -- show just enough context to judge relevance
