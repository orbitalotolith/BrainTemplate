# Word of Wisdom

Prioritized principles for AI behavior. When rules conflict, flag the conflict.

1. **Honesty** — Do not fabricate, invent, or misrepresent. Do not mislead through omission or selective framing. When uncertain, say so. Guessing and presenting as fact IS fabrication — if you lack direct evidence (tool output, file contents, explicit user statement), you do not know it. Say "I don't know" or "I'm not sure" before offering a best guess.
2. **Security** — Non-negotiable, overrides all other concerns. Evaluate security implications for any action touching data, auth, network, config, or external services — before acting.
3. **Sources** — Non-obvious claims, statistics, quotes, and dates must be sourced. If unverifiable, flag it. Default is "I need to check."
4. **Done Means Done** — If correct, leave it alone. If wrong, fix it. Never claim something works without running verification. Evidence before assertions.

# Brain

`$BRAIN_ROOT` is the Brain vault root — the nearest ancestor directory containing `_ActiveSessions/`. It is the persistent root for all Claude Code sessions. Code repos are temporary; Brain is permanent.

**Project root:** Nearest ancestor with `.git/` and `CLAUDE.md`.
**Resolving from code repos:** Follow `project_files/brain/` symlinks to locate `$BRAIN_ROOT`.

## Structure Detection

Skills locate source code in this order:
1. Project `CLAUDE.md` "Project Structure" section → parse source directories
2. Filesystem fallback → scan for `package.json`, `Cargo.toml`, `Package.swift`, `go.mod`, `pyproject.toml`

Never assume a `release/` directory exists.

## Key References

| Resource | Path |
|----------|------|
| Project registry | `_projects.conf` |
| User profile | `_Profile/index.md` (subfiles: identity, business, skills, preferences) |
| Vault architecture | `_HowThisWorks.md` |
| Plans | `_Docs/<slug>/Plans/` |
| Reports | `_Docs/<slug>/Reports/` |

All paths relative to `$BRAIN_ROOT`. `<slug>` = project slug from `_projects.conf`.

## Persistence Tiers

Five tiers, hottest to coldest. Brain holds canonical files; code repos access via `project_files/brain/` symlinks.

### 1. Session — `_ActiveSessions/<slug>/session.md`
Access: `project_files/brain/session.md`
Multi-person format: `## <username> | <date>` sections. `/save-session` writes your section only. Brain's own session file uses single-person format. Parked projects: `_ActiveSessions/_Parked/<slug>/`.

### 2. Status — `_ActiveSessions/<slug>/_Status.md`
Access: `project_files/brain/_Status.md`
Living project knowledge (Active Decisions, Gotchas). Edit in place, never append.

### 3. DevLog — `_DevLog/<slug>/YYYY-MM-DD.md`
Access: `project_files/brain/DevLog`
Write-once archive. Previous handoffs archived here. Never auto-loaded.

### 4. Memory — `_Memory/<slug>/`
Access: `~/.claude/projects/<path>/memory/` (symlinked)
Cross-project user preferences and feedback only. Not for project decisions. Global memories (`_Memory/brain/`) use copy-based sync (see `_HowThisWorks.md`).

### 5. KnowledgeBase — `_KnowledgeBase/`
General technical knowledge — platform bugs, framework quirks, cross-project gotchas. Not project-specific.

Token budget per `/start-session`: ~2K for lean projects, scales up with `_Status.md` size — a project with many active decisions and gotchas may push 5–15K tokens. `/status-audit` flags when a project's Status exceeds caps (25 decisions / 10 gotchas) so the file stays manageable.

## Knowledge Base Rules

**Write when you discover:** platform/tool bugs, framework API behaviors, or gotchas that apply across projects.

**Do NOT write:** project-specific bugs, repo-level decisions, codebase patterns — those belong in `_Status.md` or project `CLAUDE.md`.

**Mandatory:** After verifying a fix via `superpowers:systematic-debugging`, write root cause, symptoms, and fix to the relevant KB file immediately.

**Format:** Frontmatter `tags: [reference, <domain>]`, topic heading, Gotchas list. Each entry must include version/context ("as of Xcode 16") for staleness judgment. Domains: ble, ios, macos, tauri, rust, security, xcode, swift, etc.

**Pruning:** When writing a new entry, scan the same file for superseded or stale entries. Remove or update them.
