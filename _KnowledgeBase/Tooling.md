---
tags: [reference, tooling, cli]
---

# Dev Tooling

CLI tools and their setup on this machine. Use when invoking a tool and needing its config or usage pattern.

## rclone — Google Drive access

**As of:** 2026-03 (rclone 1.x, macOS)

Google Drive is accessible via `rclone` with the remote named `gdrive:`.

- **No Google Drive desktop app** is installed — don't look for local mount paths.
- Upload: `rclone copy <local_path> "gdrive:<remote_path>/" -v`
- List: `rclone lsf "gdrive:<path>/"`
