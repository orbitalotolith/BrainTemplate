# Create Project Templates

## CLAUDE.md Scaffold

```markdown
# <ProjectName>

## Project Overview
<one-line description>

## Project Structure

```
<ProjectName>/
├── core/                        # Backend / shared logic
├── tests/                       # Tests
├── config/                      # App configuration
└── project_files/               # Development support (never shipped)
    ├── brain/                   # Brain vault symlink
    │   ├── _AgentTasks/               # Symlink → Brain _AgentTasks/<slug>/ (plans, reports, specs)
    │   ├── _Status.md           # Living project knowledge
    │   ├── DevLog/              # Write-once archive
    │   └── Workbench/           # Scratch space
    └── data/                    # Runtime data (databases, generated files)
```

## Architecture
[TBD]

## Development Commands
[TBD]

## Key Dependencies
[TBD]

## Naming Conventions
[TBD]
```

## session.md Template

```markdown
---
tags: [active-session]
project: <ProjectName>
status: active
updated: <YYYY-MM-DD>
last-saved-by: <$(hostname -s)>
---

# <ProjectName>

**Current:** Initial project setup.

## Handoff
- **Left off:** Project just created
- **What got done:** --
- **Next:** Begin development
- **Context:** --
- **Code state:** Fresh repo
```

## _Status.md Template

```markdown
---
tags: [project, active]
created: <YYYY-MM-DD>
status: active
---
# <ProjectName>

## Overview
<one-line description>

## Current Focus
Initial project setup.

## Active Decisions
- None yet

## Gotchas
- None yet
```
