# Gotchas — folder-audit

| Date | Gotcha | Mitigation |
|------|--------|------------|
| 2026-04-09 | UPS checks were silently skipped during execution — agent completed SHR/SYM/STR checks but never ran UPS validation, resulting in non-standard project layouts (e.g., platform targets at repo root) going unflagged. Root cause: skill was 650+ lines across 9 check categories, too dense for reliable complete execution. | UPS checks extracted to dedicated `/structure-audit` skill. folder-audit no longer handles code repo internal layout. |
