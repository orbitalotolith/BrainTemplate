---
name: refactor
description: Use when pointed at code (file, module, function, directory) to analyze refactoring opportunities — produces sourced pros/cons and security-first recommendations without changing anything unless asked
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Glob, Grep, Read, Write, Edit, AskUserQuestion, Agent
---

# Refactor

## Overview

Analyze code for refactoring opportunities. Security is the primary lens. Every recommendation is sourced, every trade-off is explicit, and ambiguity is stated — never hidden.

**This skill is advisory by default.** It reads, reasons, and reports. It does not modify code unless the user explicitly asks.

## Arguments

- `<target>` — file path, directory, function name, or module to analyze (required)
- `--apply <ID>` — apply a specific recommendation from a previous analysis
- `--apply-all` — apply all recommendations marked RECOMMENDED
- `--security-only` — only analyze security-relevant refactoring opportunities
- `--scope <context>` — additional files/dirs for understanding call sites and dependencies
- `--resume` — resume applying recommendations from the most recent refactor report

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.

### 1. Understand Before Judging

Before analyzing anything, build context:

1. **Read the target completely.** No skimming. Every line.
   - **If the target is a directory:** Full line-by-line reading is impractical for large directories. Use this scoping strategy:
     a. **Inventory first:** Use the **Glob** tool to list all files, count total lines. If under 500 lines total, read everything.
     b. **Prioritize by risk:** Read security-relevant files first (auth, input handling, crypto, config), then files with high fan-in (many dependents), then recently changed files (`git log --since="3 months ago"`).
     c. **Deep-read priority files.** Every line, no skimming — the "read completely" rule applies per-file to files you select.
     d. **Scan remaining files** for structural patterns (imports, exports, public API surface) without full line-by-line reading. Note which files were scanned vs. deep-read in the report's Scope section.
     e. **If a scanned file triggers a concern,** promote it to deep-read before forming recommendations about it.
   - Source: McCabe (1976) — complexity management requires decomposition; applying "read every line" to unbounded input violates the cognitive complexity principles this skill cites.
2. **Read CLAUDE.md** for project conventions, architecture, naming rules.
3. **Read `project_files/brain/_Status.md`** (if exists) for Active Decisions — recent architectural changes explain why code looks the way it does.
4. **Trace dependencies.** Who calls this code? What does it call? Use the **Grep** tool to find all import/usage sites. Read the most important callers.
5. **Check git blame on surprising code.** Use the **Bash** tool to run `git blame` on code that looks wrong — a recent security fix that introduced complexity is not a refactoring target, it's load-bearing complexity.

**Do not form opinions during this phase.** Collect facts.

### 2. Security Analysis (Always First)

Every refactoring opportunity is evaluated through a security lens before anything else. This is not optional and cannot be reordered.

Analyze the target for:

| Category | What to look for | Source |
|----------|-----------------|--------|
| **Trust boundaries** | Where does untrusted data enter? Where are privilege transitions? Is validation at the boundary or scattered? | OWASP ASVS 4.0, sections 1.4 and 5.1 |
| **Attack surface** | What is publicly accessible? What can be reached with crafted input? | OWASP Attack Surface Analysis Cheat Sheet |
| **Data flow** | How does sensitive data move through this code? Is it logged, cached, serialized, or exposed? | CWE-200 (Exposure of Sensitive Information) |
| **Auth/authz coupling** | Are access checks tightly coupled to the right operations, or can they be bypassed by calling a lower-level function? | CWE-862 (Missing Authorization), CWE-863 (Incorrect Authorization) |
| **Cryptographic usage** | Hardcoded keys, weak algorithms, improper IV/nonce reuse, rolling your own crypto | CWE-327 (Broken Crypto), CWE-330 (Insufficient Randomness) |
| **Error information leakage** | Do errors reveal internals, stack traces, database schemas, file paths? | CWE-209 (Error Message Information Leak) |
| **Input validation completeness** | Is every external input validated? Type, length, range, format, encoding? | OWASP Input Validation Cheat Sheet |
| **Concurrency safety** | Race conditions on shared state, TOCTOU bugs, lock ordering | CWE-362 (Race Condition), CWE-367 (TOCTOU) |

**Security-relevant refactoring recommendations get priority over all others.** If a refactoring would improve code clarity but weaken a security property, it is rejected — note it as REJECTED with the reason.

### 3. Structural Analysis

Analyze the target across these dimensions. Not all apply to every target — skip dimensions that are irrelevant and say why.

#### 3a. Complexity

- **Cyclomatic complexity** — count decision points (if/else, switch, loops, ternary, catch). Functions above 10 are candidates; above 20 are strong candidates.
- **Cognitive complexity** — nesting depth, breaks in linear flow, number of things to hold in working memory simultaneously.
- **Coupling** — count distinct modules/classes this code depends on. High fan-out = fragile to change. High fan-in = risky to modify (many dependents).
- Source: McCabe (1976) "A Complexity Measure of Programs"; Shepperd (1988) on cognitive complexity.

#### 3b. Abstraction Health

- **Leaky abstractions** — callers that need to know implementation details to use this correctly.
- **Abstraction level consistency** — mixing high-level orchestration with low-level bit manipulation in the same function.
- **Missing abstractions** — repeated patterns across callers that should be a named concept.
- **Premature abstractions** — generic framework built for one use case. Indirection without justification.
- Source: Spolsky's Law of Leaky Abstractions; Martin (2003) on the Single Responsibility Principle.

#### 3c. Error Handling

- **Swallowed errors** — catch blocks that log and continue, or empty catch.
- **Inconsistent error strategy** — some paths throw, some return null, some return error codes.
- **Missing error paths** — operations that can fail but aren't handled (network, file I/O, parsing).
- **Error type granularity** — one generic error type vs. meaningful distinctions.
- Source: Goodenough (1975) "Exception Handling: Issues and a Proposed Notation"; Robillard & Murphy (2000) on error-handling anti-patterns in Java.

#### 3d. Type Safety and Data Integrity

- **Unsafe casts** — explicit type assertions that bypass the type system.
- **Stringly typed** — strings used where enums, tagged unions, or dedicated types would prevent invalid states.
- **Nullable fields** — fields that are sometimes undefined, requiring null checks scattered across callers.
- **Unvalidated external data** — JSON.parse, deserialization, or query results used without schema validation.
- Source: Cardelli (1996) "Type Systems"; Pierce (2002) "Types and Programming Languages" — the "make illegal states unrepresentable" principle.

#### 3e. API Surface and Encapsulation

- **Overly broad public API** — exports or public methods that are only used internally.
- **Missing encapsulation** — internal state directly accessible and mutated by external code.
- **Inconsistent interfaces** — similar operations with different signatures, parameter orders, or return types.
- Source: Parnas (1972) "On the Criteria to Be Used in Decomposing Systems into Modules"; Bloch (2006) "How to Design a Good API and Why it Matters."

#### 3f. Dependency Direction

- **Inverted dependencies** — core logic depending on infrastructure/framework details instead of abstractions.
- **Circular dependencies** — A imports B imports A (or longer cycles).
- **Unstable dependencies** — stable core code depending on frequently-changing modules.
- Source: Martin (2003) Stable Dependencies Principle, Dependency Inversion Principle.

#### 3g. Testability

- **Untestable in isolation** — requires full system setup to test a single function.
- **Hidden dependencies** — global state, singletons, ambient context that make behavior unpredictable.
- **Non-determinism** — time-dependent, random, or order-dependent behavior without injection points.
- Source: Feathers (2004) "Working Effectively with Legacy Code" — seam-based testability; Meszaros (2007) "xUnit Test Patterns" on dependency injection for testability.

#### 3h. Performance Characteristics

- **Algorithmic complexity** — O(n^2) or worse where O(n log n) or O(n) is achievable.
- **Unnecessary allocation** — creating objects/arrays in hot paths that could be reused or avoided.
- **N+1 patterns** — querying in a loop instead of batching.
- **Unbounded operations** — missing pagination, unbounded recursion, unlimited retries.
- Source: Knuth (1974) "Structured Programming with go to Statements" (premature optimization); Cormen et al. (2009) "Introduction to Algorithms" for complexity classification.

### 4. Synthesize Recommendations

For each refactoring opportunity identified, produce a structured recommendation:

```
### REF-<NNN>: <Short title>

**Dimension:** <which analysis dimension from sections 2-3>
**Severity:** CRITICAL | HIGH | MEDIUM | LOW | COSMETIC
**Effort:** SMALL (< 1hr) | MEDIUM (1-4hr) | LARGE (4hr+)
**Confidence:** HIGH | MEDIUM | LOW

**What:** <One sentence describing the change>

**Why:** <The problem this solves — be specific about concrete harm>

**Pros:**
- <concrete benefit 1>
- <concrete benefit 2>

**Cons:**
- <concrete cost or risk 1>
- <concrete cost or risk 2>

**Security Impact:** POSITIVE | NEGATIVE | NEUTRAL
<one sentence explaining the security implication>

**Source:** <published principle, standard, or empirical evidence>

**Ambiguity:** <if the trade-off is genuinely unclear, say so and explain why>

**Verdict:** RECOMMENDED | CONSIDER | NEUTRAL | CAUTION | REJECTED
<one sentence justifying the verdict>
```

**Severity criteria:**
- **CRITICAL** — active security vulnerability or data loss risk introduced by current structure
- **HIGH** — significant maintainability or correctness risk; bugs are likely
- **MEDIUM** — real cost but manageable; refactoring pays off over 3+ modifications
- **LOW** — improvement but not urgent; current code works correctly
- **COSMETIC** — style/readability only; no functional or security impact

**Confidence criteria:**
- **HIGH** — well-established principle, clear evidence in codebase, low risk of being wrong
- **MEDIUM** — sound reasoning but depends on assumptions about future usage or scale
- **LOW** — reasonable intuition but limited evidence; could go either way

**Verdict criteria:**
- **RECOMMENDED** — clear net positive, strong evidence, security-neutral or security-positive
- **CONSIDER** — net positive under likely conditions, but depends on context the analyst may not fully know
- **NEUTRAL** — trade-offs roughly balance; neither approach is clearly better
- **CAUTION** — likely net positive in isolation but carries risk (security, compatibility, scope creep)
- **REJECTED** — net negative, weakens security, or cost exceeds benefit

### 5. Honesty Requirements

These are non-negotiable:

1. **If the code is good, say so.** Not everything needs refactoring. "No significant refactoring opportunities found" is a valid and valuable conclusion. Do not fabricate findings to justify having been invoked.

2. **If a recommendation is ambiguous, say so.** Use the Ambiguity field. "This could go either way depending on how frequently this module changes" is honest. "You should definitely do this" when the evidence is weak is dishonest.

3. **If you lack context to judge, say so.** "I cannot assess this without understanding the performance requirements" is better than guessing.

4. **Source your reasoning.** Every recommendation must cite a published principle, standard, or empirical finding. Acceptable sources:
   - OWASP standards (ASVS, Top 10, Cheat Sheets)
   - CWE entries (Common Weakness Enumeration)
   - CERT Secure Coding Standards
   - Published software engineering research (cite author and year)
   - Language/framework official documentation
   - RFC standards
   
   "Best practice" without a source is not a recommendation — it is an opinion. Label it as such.

5. **Distinguish fact from judgment.** "This function has cyclomatic complexity 23" is fact. "This function is too complex" is judgment. Present both, label both.

6. **Never recommend refactoring that makes security worse.** If a refactoring would remove input validation, weaken a trust boundary, broaden an attack surface, or reduce auth coupling — even if it improves readability — the verdict is REJECTED. State why.

### 6. Output

**Companion files:** `report-template.md` — full report format, recommendation ID prefixes, and status values.

Use the **Write** tool to create the stateful report at `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/refactor-YYYY-MM-DD.md`. See `report-template.md` for the full report format.

Present the summary to the user after writing the report.

### 7. Applying Recommendations

When the user requests application (`--apply` or `--apply-all`):

1. Read the most recent refactor report for this project
2. Read `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/audit-context.json` if it exists. Note all files changed by `security-audit` or `code-audit` and the security reason for each change. Do not apply refactorings that would undo security fixes without explicit user confirmation.
3. For `--apply <ID>`: find the specific recommendation
4. For `--apply-all`: collect all RECOMMENDED verdicts, sorted by severity (CRITICAL first)
5. For each recommendation to apply:
   a. Re-read the target code (it may have changed since analysis)
   b. Verify the recommendation still applies
   c. Use the **Edit** tool to implement the change
   d. Use the **Bash** tool to run the project's build/typecheck command
   e. If the build breaks, fix it while preserving the refactoring intent
   f. Update the report: set the recommendation's Status to `APPLIED` and update the summary table counts
6. After all changes, run the full build one final time
7. Append an entry to `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/audit-context.json` (create file if it doesn't exist):
   ```json
   {
     "skill": "refactor",
     "timestamp": "ISO-8601",
     "reportFile": "$BRAIN_ROOT/_AgentTasks/<slug>/Reports/refactor-YYYY-MM-DD.md",
     "changes": [
       {
         "file": "path/to/file",
         "findingId": "REF-001",
         "action": "one-line summary of the change",
         "reason": "the refactoring reason — include security impact if any"
       }
     ],
     "compilationVerified": true
   }
   ```
   If the file already exists, append to the `entries` array. This context is read by `/code-audit` and `/security-audit` to understand what the refactoring changed.

**Never apply a REJECTED or CAUTION recommendation without explicit user confirmation.**

## Resume

When the user says "continue applying refactor recommendations", uses `--resume`, or references an existing refactor report:

1. Read the most recent `$BRAIN_ROOT/_AgentTasks/<slug>/Reports/refactor-*.md` file
2. Parse the recommendations — filter to `OPEN` status
3. Sort by severity: CRITICAL → HIGH → MEDIUM → LOW → COSMETIC
4. Present the remaining `OPEN` recommendations summary to the user
5. Ask what to apply (user picks specific IDs or "all remaining RECOMMENDED")
6. Apply recommendations, updating each status to `APPLIED` in the report as you go
7. Update the summary table counts after each application

**Status transitions:**
- `OPEN` → `APPLIED` (recommendation implemented)
- `OPEN` → `SKIPPED` (user chose to skip)
- `APPLIED` stays `APPLIED` (never reverted)
- `SKIPPED` stays `SKIPPED` (user already decided)

## Output

[TBD]

## Rules

- **Read everything before judging.** Snap judgments from skimming produce bad recommendations.
- **Security analysis always runs first** and cannot be skipped with any flag.
- **Do not modify code in the default (advisory) mode.** Analysis only.
- **Every recommendation needs a source.** No "best practice" hand-waving.
- **Ambiguity is a feature, not a failure.** Real engineering has genuinely unclear trade-offs. Say so.
- **Respect existing security measures.** Code-audit and security-audit may have already touched this code. Read `audit-context.json` if it exists.
- **Don't duplicate audit work.** If the issue is a clear violation (hardcoded secret, SQL injection), that's audit territory. Refactoring analysis is for structural improvement decisions where reasonable engineers could disagree.
