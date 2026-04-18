# Suppressions

"Keep as-is" decisions from judgment recommendations. Future runs skip suppressed findings unless the skill's content has changed since suppression date (detected via git). Changed content clears the suppression.

BHV (contract violation) findings cannot be suppressed.

| Finding | Skill | Decision | Date | Reasoning |
|---------|-------|----------|------|-----------|
| FIT-001 | pull-skills | Keep as-is | 2026-04-12 | Intentional lightweight alternative to full pull-brainshared; only syncs skills + key-to-dev.md. Useful for quick skill-only updates without full Brain sync. |
| SEC-005 | skill-audit | Keep as-is | 2026-04-13 | Process complexity is intentional — skill orchestrates 9 phases. Companion files already extract all extractable content (checks.md, report-template.md, suppressions.md, gotchas.md). |
