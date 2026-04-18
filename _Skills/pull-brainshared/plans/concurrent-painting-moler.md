# Plan: Pull-Brain Invokes Brain-Check

## Context

Pull-brain currently runs `_setup.sh` directly in Step 7 after syncing. The `/brain-check` skill already handles both `_setup.sh` AND `_health-check.sh` with proper error handling and reporting. Rather than duplicating that logic, pull-brain should invoke `/brain-check` to ensure full validation after every pull.

## Changes

### 1. Update Step 7 in SKILL.md (line ~312-318)

**Current:**
```markdown
### 7. Propagate to Claude

Run `_setup.sh` to re-seed memories and update symlinks:

```bash
bash "$BRAIN/_setup.sh"
```
```

**New:**
```markdown
### 7. Propagate to Claude and Validate

Invoke `/brain-check` to run `_setup.sh` (re-seed memories, fix symlinks) and `_health-check.sh` (validate vault integrity).

Health check failures are **warnings, not blockers** — the pull has already been applied. The user should review and fix, but the skill continues to commit.
```

### 2. Update CONTRACT.md — BHV-5 (line 12)

**Current:**
> MUST run _setup.sh after sync to propagate changes to ~/.claude/ (symlinks and memory seeding).

**New:**
> MUST invoke /brain-check after sync to propagate changes to ~/.claude/ and validate vault integrity.

### 3. Update Step 10 cleanup message (line ~378)

Remove the line `echo "Run _health-check.sh to verify vault integrity."` — redundant since `/brain-check` already ran it.

### 4. Update allowed-tools in frontmatter (line 6)

**Current:** `allowed-tools: Bash, Read, Write, AskUserQuestion`

**New:** `allowed-tools: Bash, Read, Write, AskUserQuestion, Skill`

The `Skill` tool is needed to invoke `/brain-check`.

## Files Modified

- `SKILL.md` — frontmatter (allowed-tools), Step 7 updated, Step 10 cleanup message trimmed
- `CONTRACT.md` — BHV-5 updated

## Verification

1. Run `/pull-brain` and confirm `/brain-check` is invoked after sync (both `_setup.sh` and `_health-check.sh` output visible)
2. Confirm health check failures don't block the commit step
3. Confirm cleanup message no longer tells user to run health check manually
