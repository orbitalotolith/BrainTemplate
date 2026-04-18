# Contract — save-session

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID  | Invariant                                                                                                                                                                                                                                            |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Every save MUST scan the conversation for new knowledge (memories, feedback, KB entries, profile updates) and write anything found. No tier skips knowledge capture.                                                                                 |
| 2   | Every save MUST sync memories back to Brain git (step 8b). No exceptions.                                                                                                                                                                            |
| 3   | Every save MUST update the AS file to reflect current state — at minimum append, never skip entirely.                                                                                                                                                |
| 4   | Every save MUST write the timestamp (step 10) and show git status (step 11).                                                                                                                                                                         |
| 5   | The "Code state" line in the AS file MUST be populated from verified git output, never from session memory.                                                                                                                                          |
| 6   | The "Next" and "Next session" lines MUST NOT mention committing or git operations as suggested actions.                                                                                                                                              |
| 7   | DevLog archiving and full AS narration MAY be deferred to substantial saves. These are the only deferrable steps.                                                                                                                                    |
| 8   | Brain git commit MUST NOT auto-commit. Must offer and wait for user confirmation. Only runs on substantial saves. If the user agrees to commit, MUST invoke `/commit` — never commit with raw git commands.                                          |
| 9   | _Status.md MUST be edited in place — never appended, never overwritten wholesale.                                                                                                                                                                    |
| 10  | Tier classification MUST be content-based ("did anything worth narrating happen?"), not time-based.                                                                                                                                                  |
| 11  | The goal of every save is to ensure the AI continuously improves its understanding of WHY and HOW decisions are made, not just WHAT was done. Knowledge capture is the priority; speed is achieved by deferring narration, not by skipping learning. |
