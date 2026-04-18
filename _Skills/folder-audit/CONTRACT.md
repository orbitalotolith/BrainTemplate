# Contract — folder-audit

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | The full audit (Phases 1-3) must complete and the report must be presented to the user before any filesystem writes occur. No repairs happen until Phase 4, after explicit user approval via AskUserQuestion. |
| 2  | Working symlinks are never removed, overwritten, or re-created unless the user has confirmed the specific repair. Before replacing any symlink, verify the existing target resolves (`[ -e "$link" ]`); if it resolves, treat it as working and require per-item confirmation. |
| 3  | Non-empty directories and non-empty files are never deleted without per-item user confirmation. Group 5 (moves) and Group 6 (format conversion) require per-project confirmation — never batch these. |
| 4  | All project resolution — slug lookup, notes path, code path — derives from `_projects.conf`. No secondary mapping files, hardcoded project lists, or assumptions from directory names alone are used to resolve project identity. |
| 5  | Structural rules (naming conventions, required subdirectories, symlink architecture) are read from `_HowThisWorks.md` at runtime. The skill never hardcodes structural expectations that contradict or duplicate what that file defines. |
| 6  | After all approved repairs complete, `_health-check.sh` runs automatically as verification. The skill never auto-commits or auto-pushes to any git repository. |
| 7  | If the audit produces zero findings, the skill reports that the structure is clean and stops. It does not manufacture findings, suggest optional improvements, or propose speculative changes. |
| 8  | Downgrade rules are applied before reporting: STR-002 (orphaned notes) downgrades to info when `_Status.md` has `status: planning` or `status: archived`; SYM-004 (dangling CLAUDE.md symlink) downgrades to info when the code repo is not cloned on the current machine. Severities are never inflated beyond what the evidence supports. |
