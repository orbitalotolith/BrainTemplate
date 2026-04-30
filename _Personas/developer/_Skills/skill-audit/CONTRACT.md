# Contract — skill-audit

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | Phases execute in strict order: discovery before lint, lint before analyze, analyze before report, report before repair. No phase may run before its predecessors complete. |
| 2  | The report file must be written with all findings before any repair actions modify skill files. Repairs never run on unreported findings. |
| 3  | Mechanical auto-fixes (FMT, SEC, NAM, GOT) are applied only after user selects a repair option from the menu. Discovery, lint, and analyze phases never modify skill files. |
| 4  | BHV-001 through BHV-004 contract violations are never auto-fixed, never suppressed, and always presented to the user with the exact invariant and corresponding process step (or absence) quoted side by side. |
| 5  | After each auto-fix modifies a file, the file must be re-read and verified before proceeding to the next fix. No fix is applied against stale file content. |
| 6  | Section reordering (SEC-002 fix) must preserve all content within each section. Line count of non-whitespace content before and after reordering must be equal. |
| 7  | Judgment findings (FIT, INV, SCP, CMP, BHV-005) are never auto-fixed. Each is presented individually with evidence, and the user chooses the disposition (action, keep-as-is, or defer). |
| 8  | In full mode, self-audit of skill-audit runs before any other skill is checked. Self-audit findings are presented with fix/skip/abort options before proceeding. |
| 9  | When auto-fixes are applied, they execute in strict group order: FMT fixes first, then SEC, then NAM, then GOT. No fix in a later group runs until all fixes in earlier groups are complete and verified. This ordering is load-bearing: GOT-004 inserts into `## Process`, which SEC-002 may be repositioning — GOT must run after SEC to insert into the correct final location. |
