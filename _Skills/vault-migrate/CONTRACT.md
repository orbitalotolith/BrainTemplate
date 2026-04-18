# Contract — vault-migrate

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | The skill must never modify vault files directly. Its only write output is the migration plan file saved to `_Docs/brain/Plans/`. All structural changes happen during plan execution via superpowers. |
| 2  | Phase 1 (Deep Diff) must compare against both `_HowThisWorks.md` (expected structure) and BrainShared remote content (cloned to temp dir, partner state) when in post-pull or pre-push mode. Comparing against only one source is a violation. |
| 3  | Phase 3 (Interactive Q&A) must ask at least one clarifying question via AskUserQuestion when ambiguous changes are detected (e.g., directory disappeared — moved or deleted?). Generating a plan without resolving ambiguities is a violation. |
| 4  | Generated plans must enumerate every affected project by slug with specific file paths. Plans that use "repeat for all projects" or similar shorthand instead of explicit per-project steps are a violation. |
| 5  | Generated plans must order phases by dependency: emergency fixes → documentation → file moves → config migration → per-repo updates → symlink rewiring → cleanup → validation. Source-of-truth files must be updated before consumer files in the plan. |
| 6  | When analysis detects `_ActiveSessions` rename, `project_files/brain` convention change, or `_projects.conf` format change, the skill must emit a HIGH/CATASTROPHIC severity warning and require explicit user acknowledgment before including it in the plan. |
| 7  | Pre-push mode must validate local vault consistency against BrainShared expectations. It must not generate a migration plan that modifies BrainShared content — only local vault adjustments. |
| 8  | If zero structural differences are detected, the skill must report consistency and exit. It must not manufacture migration work or generate an empty plan. |
