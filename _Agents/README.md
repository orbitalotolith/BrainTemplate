# `_Agents/` — runtime agents that consume Brain content

This directory is for AI agents that **run outside Claude Code** and need to read from / write to the Brain vault at runtime. Distinct from `_projects.conf` slugs (which track code repos Claude Code works on).

## Convention

```
_Agents/
├── README.md                ← this file
└── <agent-name>/
    ├── persona.yaml         ← identity, personality, constraints (loaded at startup)
    ├── standing-context.md  ← pointers the agent loads at startup (user profile, project registry, etc.)
    └── memory/              ← agent's private notes (writable by the agent)
        ├── MEMORY.md        ← index (agent builds this over time)
        └── *.md             ← individual memory entries
```

## Read/write model

An agent in `_Agents/<name>/` typically has:

- **Read access** to a curated set of Brain subtrees (`_Profile/`, `_ActiveSessions/`, `_DevLog/`, `_Memory/`, `_KnowledgeBase/`, `_Docs/`, `_Workbench/`, `_projects.conf`, its own `_Agents/<name>/`). The agent's read whitelist is enforced by its runtime (e.g., a bridge module in the agent's host process).
- **Write access** to a narrow set of targets:
  - `_Docs/<slug>/` — plans, reports, and artifacts the agent creates on behalf of a project
  - `_Workbench/<slug>/` — quick notes, scratch work
  - `_Agents/<name>/memory/` — its own private notes
- **No write access** to `_Profile/`, `_ActiveSessions/*/_Status.md`, `_KnowledgeBase/`, `_projects.conf`, `_ClaudeSettings/`, or `_Skills/`. Those are human-curated (or Claude-Code-curated via skills like `/save-session`).

## Why this is separate from project slugs

Project slugs in `_projects.conf` exist so Claude Code sessions can map a working directory to Brain artifacts (`_ActiveSessions/<slug>/`, `_Memory/<slug>/`, etc.) via `project_files/brain/` symlinks. Agents in `_Agents/` aren't code repos — they're processes that **consume** the vault. No symlinks, no code-repo mapping.

## Adding an agent

Create `_Agents/<agent-name>/` following the convention above. Populate `persona.yaml`, `standing-context.md`, and an empty `memory/` directory. The runtime that hosts the agent symlinks into Brain so `_Agents/<agent-name>/persona.yaml` is the canonical source of truth.
