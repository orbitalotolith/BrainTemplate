---
name: create-matter
description: Create a new legal matter with status, registry entry, and optional external folder. Use when user says "create a matter", "new matter", or wants to start tracking a new case/contract/advisory.
allowed-tools: Read, Write, Edit, Bash
---

# /create-matter

Create a new matter — a legal-practice unit of work analogous to a project.

## Inputs (ask the user one at a time)

1. **Matter slug** — lowercase, hyphenated, e.g., `acme-acquisition`. Used as the directory name.
2. **Client name** — free-form. Same client can have multiple matters.
3. **Type** — one of: `contract` / `litigation` / `advisory` / `drafting` / `regulatory`
4. **External folder?** (Y/n) — default Y for doc-heavy matters. If Y, create `~/Legal/<slug>/documents/` for raw PDFs.

## Validation

- Slug must match `^[a-z0-9][a-z0-9-]*$`. Reject anything else.
- Slug must not collide with existing entry in `_matters.conf`. Check with: `grep "^${SLUG}|" "$BRAIN_ROOT/_matters.conf"`.
- Type must be one of the five allowed values.

## Steps

1. Read `_matters.conf` to confirm slug is unique. If not, ask user for a different slug.
2. If external folder requested:
   - Create `~/Legal/<slug>/documents/` via `mkdir -p`.
   - Create symlinks (deferred to Plan 2 — not needed for MVP).
3. Append entry to `_matters.conf`:
   ```
   <slug>|<client>|<type>|<external_path_or_empty>|active
   ```
4. Create `_ActiveSessions/<slug>/` directory.
5. Render `_Templates/MatterStatus.md` to `_ActiveSessions/<slug>/_Status.md`, substituting:
   - `{{SLUG}}` → matter slug
   - `{{CLIENT}}` → client name
   - `{{TYPE}}` → matter type
   - `{{EXTERNAL_PATH}}` → external path (empty if no external folder)
   - `{{CREATED}}` → ISO 8601 UTC timestamp
6. Create `_Memory/<slug>/` directory with empty `MEMORY.md` (header only).
7. Confirm to user: matter <slug> created, location of status file, location of external folder if any.

## Anti-hallucination

This skill creates structure, no content claims. No special enforcement needed beyond the persona-level CLAUDE.md rules.

## Example

User: "Create a new matter for Acme acquisition."
You: "OK — slug for the matter? (e.g., 'acme-acquisition')"
User: "acme-acquisition"
You: "Client name?"
User: "Acme Corp"
You: "Type? (contract/litigation/advisory/drafting/regulatory)"
User: "contract"
You: "External folder for documents at ~/Legal/acme-acquisition/? (Y/n)"
User: "Y"
You: [create directories, append to _matters.conf, render status template]
You: "Matter `acme-acquisition` created. Status: `_ActiveSessions/acme-acquisition/_Status.md`. Documents folder: `~/Legal/acme-acquisition/documents/`."
