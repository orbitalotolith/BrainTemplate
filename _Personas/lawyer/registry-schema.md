# `_matters.conf` Schema

Pipe-delimited registry. One line per matter. Comment lines start with `#`.

## Format

```
SLUG|CLIENT|TYPE|EXTERNAL_PATH|STATUS
```

## Fields

| Field | Required | Description |
|-------|----------|-------------|
| `SLUG` | yes | Matter identifier. Lowercase, hyphenated. Used in `_ActiveSessions/<slug>/`, `_Memory/<slug>/`, etc. |
| `CLIENT` | yes | Client name (free-form). Multiple matters can share a client. |
| `TYPE` | yes | One of: `contract`, `litigation`, `advisory`, `drafting`, `regulatory` |
| `EXTERNAL_PATH` | no | Path relative to `~/Legal/` (e.g., `acme-acquisition`). Empty = in-Brain only. |
| `STATUS` | yes | One of: `active`, `closed`, `on-hold` |

## Example

```
acme-acquisition|Acme Corp|contract|acme-acquisition|active
smith-vs-doe|Smith Industries|litigation|smith-vs-doe|active
quick-advisory|Beta LLC|advisory||closed
```

## Adding a matter

Use the `/create-matter` skill — it appends to this file and creates the necessary directories.
