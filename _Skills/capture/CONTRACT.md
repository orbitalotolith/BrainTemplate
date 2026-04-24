# Contract — capture

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | MUST NOT route or cleanup existing entries. `/status-audit` owns that. `/capture` only adds new entries or replaces targeted sections. |
| 2  | Every `_Status.md` or `_KnowledgeBase/` entry MUST carry a `(YYYY-MM-DD)` date prefix (status) or version/context tag (kb). |
| 3  | After any `_Status.md` write, MUST count entries in Active Decisions and Gotchas. If either exceeds its cap (25 / 10), emit a single ⚠ cap-warning line in the output. |
| 4  | Silent mode (`--silent`) MUST NOT invoke `AskUserQuestion`. If required info is missing, fail loud with a structured error prefixed `ERROR:` and exit. |
| 5  | Interactive mode MUST confirm each item individually before writing (one `AskUserQuestion` per item). |
| 6  | MUST resolve `<slug>` via save-session rules a-e. Silent callers pass `--slug=<x>` to skip resolution. |
| 7  | MUST NOT write to `$BRAIN/_Agents/oto/memory/` — that is oto's private scratchpad, written only by the agent itself via `vault_write`. |
| 8  | `profile` and `oto` writes MUST be edit-in-place, not append. Fail loud if the target section (profile) or field (oto) is not specified. |
| 9  | Bulk invocations from `/save-session` and `/save-lightweight` MUST arrive as one `/capture` call per item — no batched arrays. |
| 10 | Every successful write MUST produce a one-line confirmation to the caller showing destination path and entry summary. |
