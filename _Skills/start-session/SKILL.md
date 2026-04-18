---
name: start-session
description: Start or continue a work session — load context from active session and project status
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read, AskUserQuestion
---

# Session Start

Load context from the vault and present a summary so work can resume.

## Overview

Locates the active session for the current working directory and presents a concise context summary so work can resume without re-reading files.

## Process

### 0. Read Gotchas

Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### 1. Resolve Project Slug

Use the **Bash** tool to resolve the Brain root and current working directory.

1. Read `$BRAIN/_projects.conf` (locate Brain root via `$BRAIN_ROOT` or by finding the nearest ancestor containing `_ActiveSessions/`).
2. Get CWD. Strip `~/Development/` prefix to get the relative path.
3. Match against `CODE_PATH` entries from the registry (longest prefix wins). The matching `SLUG` is the project slug.
4. If CWD is under `$BRAIN/_Workbench/<slug>/`, extract `<slug>` directly.
5. If no match: "No project found for this directory. Add an entry to `_projects.conf` and create `_ActiveSessions/<slug>/`." — then stop.

### 2. Load Context

Read these two files (skip any that don't exist):

- `$BRAIN/_ActiveSessions/<slug>/session.md` — handoff, current state, next steps
- `$BRAIN/_ActiveSessions/<slug>/_Status.md` — current focus, active decisions, gotchas

### 3. Present

Concise summary, 20 lines max:

- **Last handoff** — what was being worked on, where it left off, next steps, code state
- **Active decisions** — names only, from `_Status.md`
- **Gotchas** — all, from `_Status.md`

### 4. Prompt

Use **AskUserQuestion** to ask: "Continue from where you left off, or start something new?"

## Rules

- Read-only — does not modify any files
- Only loads session.md and _Status.md — everything else (CLAUDE.md, memories, KB) is handled by the system or other skills
- No git operations — no pull, no status, no sync
- If a file doesn't exist, skip it silently and present what's available

## Output

A concise context summary (≤20 lines):
- **Last handoff** — what was being worked on, where it left off, next steps, code state
- **Active decisions** — names only, from `_Status.md`
- **Gotchas** — all items from `_Status.md`
- A prompt: "Continue from where you left off, or start something new?"
