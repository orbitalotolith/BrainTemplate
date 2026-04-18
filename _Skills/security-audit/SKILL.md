---
name: security-audit
description: Audit codebase for security vulnerabilities, dependency health, and deployment readiness
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Glob, Grep, Read, Write, Edit, AskUserQuestion
---

# Security Audit

Project-type-agnostic security, dependency, and deployment readiness audit. Finds issues and fixes them (or reports in dry-run mode). See CLAUDE.md "Workflow Conventions" for standard paths.

## Overview

[TBD]

## Arguments

- `--dry-run` — report issues without making changes
- `--secrets-only` — only run secrets detection (section 1)
- `--deps-only` — only run dependency health checks (section 4)
- `--deploy-only` — only run deployment readiness checks (section 5)
- `--scope <path>` — limit audit to specific files or directories
- `--resume` — continue fixing findings from the most recent security audit report

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### Preamble

1. Detect source paths using the following fallback chain:
   - **CLAUDE.md:** Read project-level `CLAUDE.md` and parse source directories from any "Project Structure" or "Architecture" section
   - **Filesystem scan:** If no structure section, scan for `package.json`, `Cargo.toml`, `Package.swift`, `go.mod`, `pyproject.toml` — source directories = directories containing these manifests
2. Read project-level `CLAUDE.md` for architecture, naming conventions, and patterns
3. Determine which audit categories apply based on the project type
4. Skip categories that don't apply (e.g., skip DPL- Tauri checks for a web app)
5. Create `$BRAIN_ROOT/_Docs/<slug>/Reports/` directory if it doesn't exist (resolve slug from `_projects.conf`)

### Audit Categories

#### 1. Secrets Detection (`SEC-`)

Search for hardcoded secrets using patterns:
- `password\s*[:=]`, `api_key\s*[:=]`, `secret\s*[:=]`, `token\s*[:=]`
- `-----BEGIN.*PRIVATE KEY-----`
- Connection strings with embedded credentials
- `.env` files committed to git (check git history too)
- API keys, passwords, tokens in source code
- Data protection — sensitive data logged, stored unencrypted, or transmitted insecurely

#### 2. Code Vulnerabilities (`VUL-`)

Review all source code for:
- **Injection risks** — SQL injection (string concatenation in queries, non-parameterized queries), XSS (innerHTML, dangerouslySetInnerHTML without sanitization, unescaped user input), command injection (exec/spawn/eval with user input)
- **Path traversal** — user input in file paths without validation
- **Auth/authz issues** — missing authentication checks on routes, privilege escalation paths, weak session handling, insecure cookies
- **Input validation** — all user-facing inputs sanitized and validated
- **Error handling that leaks info** — stack traces, internal paths, or sensitive data in error responses

#### 3. Configuration Issues (`CFG-`)

- Debug mode in production configs
- CORS wildcard (`*`) or overly permissive origins
- Missing security headers
- HTTP instead of HTTPS
- **Tauri:** Review `tauri.conf.json` permissions/allowlist — flag overly broad permissions
- **iOS:** Review `Info.plist` — flag unnecessary permission requests (camera, location, etc.)

#### 4. Dependency Health (`DEP-`)

**4a. Vulnerability Scan**

Use Bash to run the appropriate scanner based on project type. Use Edit to fix vulnerabilities in source code:
- **Node.js:** `npm audit` (or `yarn audit`)
- **Rust:** `cargo audit` (if installed; suggest installing if not)
- **Python:** `pip-audit` (if installed; suggest installing if not)
- **Go:** `govulncheck` (if installed)
- **Tauri (monorepo):** Run both `npm audit` AND `cargo audit`

Report CVEs with severity, affected package, and fix version.

**4b. Outdated Dependencies**

Run the appropriate checker:
- **Node.js:** `npm outdated`
- **Rust:** `cargo outdated` (if installed)
- **Python:** `pip list --outdated`
- **Go:** `go list -m -u all`

Flag major version gaps (likely breaking changes) separately from minor/patch updates.

**4c. Unused Dependencies**

Scan imports/requires across source files and compare to declared dependencies:
- **Node.js:** Grep for `import ... from` and `require(...)` across source, compare to package.json `dependencies` and `devDependencies`
- **Rust:** Grep for `use <crate>` and `extern crate`, compare to Cargo.toml `[dependencies]`
- **Python:** Grep for `import` and `from ... import`, compare to requirements.txt
- Flag deps declared in manifest but not imported anywhere in source

**4d. License Compatibility**

List licenses of all dependencies:
- **Node.js:** Parse package-lock.json or use `npm ls --json`
- **Rust:** `cargo license` (if installed) or parse Cargo.lock metadata
- Flag:
  - **Copyleft licenses** (GPL, AGPL) in commercial/proprietary projects
  - **Unknown/missing licenses** — potential legal risk
  - **License changes** — deps that changed license in newer versions

#### 5. Deployment Readiness (`DPL-`)

**Detect project type** from filesystem (package.json, Cargo.toml, etc.), then run the applicable checks.

**Web / API:**

| Check | How |
|-------|-----|
| Dockerfile exists and builds | `docker build` in project root or `sourcePaths` |
| docker-compose.yml is valid | `docker-compose config` |
| .env.example exists | Glob for .env.example in project root or `sourcePaths` |
| .env.example covers all env vars | Grep for `process.env.` / `os.environ` in source, compare to .env.example |
| Health check endpoint exists | Grep for `/health` or `/api/health` route |
| No hardcoded localhost/dev URLs | Grep for `localhost`, `127.0.0.1`, hardcoded ports in production code |

**Tauri Desktop:**

| Check | How |
|-------|-----|
| CI/CD workflow exists | Glob for `.github/workflows/*.yml` |
| Version consistent | Compare version in tauri.conf.json, Cargo.toml, and package.json |
| App icons configured | Check tauri.conf.json icon paths exist |
| Tauri permissions minimal | Review tauri.conf.json allowlist for unnecessary entries |

**iOS:**

| Check | How |
|-------|-----|
| Bundle identifier configured | Check Info.plist or Package.swift |
| Info.plist permissions documented | List all permission keys, verify each has usage description |
| No debug flags in release config | Grep for `#if DEBUG` that leaks into release, hardcoded test data |

**CLI:**

| Check | How |
|-------|-----|
| Build/install instructions in README | Check README for build and install sections |
| Version flag implemented | Grep for `--version` or `-V` handling |
| Package distribution configured | Check for publish config in Cargo.toml / setup.py / package.json |

**All Types:**

| Check | How |
|-------|-----|
| No TODO/FIXME in critical paths | Grep for TODO, FIXME, HACK, XXX in source (report count) |
| CLAUDE.md version matches actual | Compare version in CLAUDE.md to config files |

### Execution

1. **Analyze structure** — identify component boundaries, languages, and project type
2. **Run all applicable categories** — sections 1–5 in order: secrets → code vulnerabilities → configuration → dependency health → deployment readiness. Collect findings with IDs.
3. **Root cause analysis** — group findings by class (not just category). For each group, ask: "What systemic gap allows this class of problem to exist?" Examples:
   - Multiple hardcoded secrets → no secrets management pattern (missing `.env` convention, no pre-commit hook)
   - Multiple injection vulnerabilities → no input sanitization layer or convention
   - Multiple missing auth checks → no middleware/guard pattern enforced
   - Multiple outdated deps → no dependency update process

   Each class gets a root cause entry (prefixed `RC-`) in the report. Individual findings link back to their root cause. A single finding can still have a root cause if the systemic gap is real.
4. **Compile report** — write all findings to `$BRAIN_ROOT/_Docs/<slug>/Reports/security-YYYY-MM-DD.md` in the unified report format.
5. **Prioritize findings:** CRITICAL → HIGH → MEDIUM → LOW
6. In default mode: present the report and ask the user what to fix (see Post-Audit)
7. In `--dry-run` mode: write the report and stop — do not fix anything

### Severity

Assign severity directly:
- **CRITICAL** — exploitable security vulnerability, data loss risk, or known CVE with exploit
- **HIGH** — security weakness, significant auth/authz gap, or vulnerable dependency with available fix
- **MEDIUM** — configuration issue, minor security concern, outdated dependency with breaking change, or deployment gap
- **LOW** — informational, license review item, minor update available

## Companion Files

- `report-template.md` — full report format, finding ID prefixes, and status values

## Output

All audit runs produce a stateful report at `$BRAIN_ROOT/_Docs/<slug>/Reports/security-YYYY-MM-DD.md`. See `report-template.md` for the full report format.

### Post-Audit

After writing the report, present the summary table to the user and ask what to fix using AskUserQuestion:
- "Fix all issues" — fix everything, starting with highest severity
- "Fix by severity" — ask which severity level(s) to fix (CRITICAL, HIGH, MEDIUM, LOW)
- "Fix specific IDs" — let user pick individual finding IDs
- "No fixes needed" — end the audit

When fixing issues:
1. **Fix systemic gaps first** — for each root cause (RC-), implement the principle fix (the convention, tooling, or pattern that prevents the class). This may resolve some individual findings automatically. Mark resolved findings as `FIXED`.
2. **Then fix remaining instances** — in severity order: CRITICAL → HIGH → MEDIUM → LOW. After the systemic fix is in place, these are cleanup of existing occurrences.
3. After each fix, update the finding's status to `FIXED` in the report file
4. Update the summary table counts after each fix
5. **Verify compilation** — after all fixes are applied, run the project's typecheck/build command (detected from project config). If compilation fails:
   - Identify which security fix caused the breakage
   - Fix the compilation error while preserving the security remediation
   - Update the finding's detail section with a note about the compilation fix
   - Re-run the build to confirm
   - Never leave the codebase in a broken state after a security audit
6. **Write audit context** — append an entry to `$BRAIN_ROOT/_Docs/<slug>/Reports/audit-context.json` (create file if it doesn't exist):
   ```json
   {
     "entries": [
       {
         "skill": "security-audit",
         "timestamp": "ISO-8601",
         "reportFile": "$BRAIN_ROOT/_Docs/<slug>/Reports/security-YYYY-MM-DD.md",
         "changes": [
           {
             "file": "path/to/file",
             "findingId": "VUL-001",
             "action": "one-line summary of the change",
             "reason": "the security reason behind it"
           }
         ],
         "compilationVerified": true
       }
     ]
   }
   ```
   If the file already exists, append to the `entries` array. This context is read by `/code-audit` to avoid reverting security changes.
7. **Next steps** — note: "Run `/code-audit` to address code quality in security-modified files. Code audit will respect all security fixes."

## Resume

When the user says "continue fixing security findings", uses `--resume`, or references an existing security audit report:

1. Read the most recent `$BRAIN_ROOT/_Docs/<slug>/Reports/security-*.md` file (legacy fallback: `.claude/reports/security-*.md`)
2. Parse the findings table — filter to `OPEN` findings
3. Sort by severity: CRITICAL → HIGH → MEDIUM → LOW
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
