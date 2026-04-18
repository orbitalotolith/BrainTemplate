---
tags: [reference, swift, sqlite, grdb]
---

# SQLite Date Handling & GRDB

Gotchas for date formatting and type inference when using SQLite from Swift, especially with GRDB.

## Gotchas

- **ISO8601DateFormatter vs SQLite CURRENT_TIMESTAMP format mismatch** (not version-specific) — Swift's `ISO8601DateFormatter()` produces `2026-03-07T12:00:00Z` (with `T` separator and `Z` suffix). SQLite's `CURRENT_TIMESTAMP` produces `2026-03-07 12:00:00` (space-separated, no timezone indicator). Date comparisons in sync queries (`updated_at > ?`) silently break when formats differ because SQLite compares these as strings. Fix: either use `strftime('%Y-%m-%dT%H:%M:%SZ')` in SQL to match ISO8601 format, or normalize dates in Swift before comparison.

- **GRDB nullable column type inference crashes on NULL** (as of GRDB 6.x) — `row["column"]` infers the return type from the call site. If the column value is NULL and the target type is non-optional (e.g., `let date: Date = row["deleted_at"]`), it crashes at runtime with no compile-time warning. Always use optional types for nullable columns: `let date: Date? = row["deleted_at"]`. Common nullable columns that trigger this: `deleted_at`, `last_sync_at`, `error_message`, `entry_uuid`.
