# Contract — brand-identity-extractor

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | The skill must not write `_Brand.md` without explicit user confirmation via AskUserQuestion. Present the extracted brand summary first; only write the file after approval. |
| 2  | Phase 1 (URL fetch) must complete before any brand extraction begins. The skill must not infer brand identity from directory names, project names, or cached state — only from live website content. |
| 3  | If `_Brand.md` already exists in the client directory, the skill must diff proposed changes against the existing file and confirm overwrites item-by-item via AskUserQuestion rather than replacing wholesale. |
| 4  | If the client directory does not exist, the skill outputs the brand guide to terminal only. It must not create directories or files outside `~/Development/<ClientName>/`. |
| 5  | CSS reconciliation (matching extracted brand to existing design system CSS) is always presented as suggestions, never auto-applied. Changes to CSS files require explicit user approval. |
| 6  | The skill must not store or log raw website content. Only the extracted brand attributes (colors, typography, tone) are retained for output. |
