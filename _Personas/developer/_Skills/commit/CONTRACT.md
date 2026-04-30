# Contract — commit

Behavioral invariants for this skill. Checked by `/skill-audit` (BHV-001 through BHV-004).
Violations are errors — the skill or the contract must be updated to resolve them.

| ID | Invariant |
|----|-----------|
| 1  | Repo scope gate: MUST block commits to BrainShared (detected by remote URL or repo path) and collab projects (detected by `COLLAB=collab` in `_projects.conf`). Only Brain (personal) and solo personal projects are allowed. |
| 2  | Pre-commit checks (git identity, no .claude/, no secrets, no Claude artifacts, path validation) MUST run before any staging. If any check fails, do NOT commit. |
| 3  | Commit messages MUST NOT contain Co-Authored-By, co-authored-by, Signed-off-by, or any AI/tool attribution lines — not in subject, body, or trailer. |
| 4  | `/commit` without "push" argument MUST only commit locally. MUST NOT push, ask about pushing, or suggest pushing. |
| 5  | `/commit push` MUST commit then push. If no upstream is set, use `git push -u origin <branch>`. |
| 6  | Commit message subject MUST be under 72 characters, imperative mood, Conventional Commits format. |
| 7  | Local git identity (user.name + user.email) MUST be verified before committing. Block and show setup instructions if either is missing. |
| 8  | Before committing, MUST display the repo name and remote URL and ask the user to confirm it is the correct repository. Never commit to an unconfirmed repo. |
