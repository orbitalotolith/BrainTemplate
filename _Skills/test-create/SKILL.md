---
name: test-create
description: Generate tests for existing code using the project's test framework
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Glob, Grep, Read, Write, AskUserQuestion
---

# Test Create

Generate tests for existing code. Detects the project's test framework or suggests one if none exists. See CLAUDE.md "Workflow Conventions" for standard paths.

## Overview

[TBD]

## Arguments

- `--file <path>` — generate tests for a specific file
- `--coverage` — show untested public functions/methods across the project
- `--setup` — configure test framework (install deps, create config, add test script)

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

> **Note:** This skill generates tests for existing untested code. For new feature development, prefer `superpowers:test-driven-development` which follows the RED-GREEN-REFACTOR cycle.

### 1. Detect Test Framework

Locate source directories using the standard Structure Detection order (see CLAUDE.md). Use Glob to find config files (`package.json`, `Cargo.toml`, `Package.swift`, etc.) and Grep to scan them for test framework markers:

- **JavaScript/TypeScript:** Check package.json for vitest, jest, mocha, or test scripts
- **Rust:** Built-in `#[cfg(test)]` modules, or check for cargo-nextest
- **Swift:** XCTest (check for test targets in Package.swift or .xcodeproj)
- **Python:** Check for pytest.ini, setup.cfg [tool:pytest], pyproject.toml [tool.pytest], or unittest patterns
- **Go:** Built-in `testing` package

If no framework found: suggest the most appropriate one for the project type and offer to set it up.

### 2. Determine What to Test

Use AskUserQuestion (or accept flags) to determine scope:

- **Specific file/function:** `--file path/to/file.ts`
- **Untested code paths:** `--coverage` — analyze which public functions lack tests
- **All public APIs:** Test all exported/public functions and endpoints

### 3. Generate Tests

Follow project conventions for:

- **Test file location:**
  - Colocated: `Component.test.tsx` next to `Component.tsx`
  - Separate directory: `tests/`, `__tests__/`, `src-tauri/src/` (Rust inline)
  - Read from existing test files if any exist to match the pattern

- **Test file naming:**
  - TypeScript/JavaScript: `*.test.ts`, `*.spec.ts`
  - Rust: `#[cfg(test)] mod tests` inline, or `tests/*.rs` for integration
  - Swift: `*Tests.swift`
  - Python: `test_*.py`

- **Test structure:**
  - Group by function/method being tested
  - Cover: happy path, edge cases, error cases
  - Use descriptive test names that explain the scenario
  - Mock external dependencies (APIs, databases, file system)

### 4. Run Tests

Use Bash to execute the test suite and verify generated tests pass. Use Write to create new test files in the detected framework's conventions.

## Output

[TBD]

## Rules

- Match existing test patterns if any tests already exist
- Don't over-mock — test real behavior where practical
- Don't test private/internal functions directly — test through public API
- Each test should be independent — no shared mutable state between tests
- Include both positive and negative test cases
