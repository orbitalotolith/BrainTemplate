---
tags: [reference, tauri]
---
# Tauri Development Notes

## Overview
Tauri 2.0 — Rust backend + web frontend (React, Vue, etc.). Ships native webview, no Electron/Chromium.

## IPC Pattern
- Frontend calls `invoke("command_name", { params })` from `@tauri-apps/api/core`
- Params must match Rust function argument names **exactly** (e.g., `device_id` not `deviceId`)
- Rust commands return `Result<T, String>` — errors surface as rejected promises

## Multi-Platform Builds
- GitHub Actions can build for Linux (`.deb`, `.AppImage`) and Windows (`.exe`, `.msi`)
- macOS builds need macOS runner
- Version in `tauri.conf.json` determines installer filename
- `Cargo.toml` and `package.json` versions should stay in sync

## Common Gotchas
- **Stale build cache:** After restructuring directories or renaming, run `cargo clean` (timeless Cargo behavior)
- **Plugin permissions:** Unused plugins (e.g., `tauri-plugin-shell`) can grant unnecessary permissions — remove them (as of Tauri 2.0)
- **CSP:** Set strict CSP in `tauri.conf.json`. Avoid `unsafe-inline`. (as of Tauri 2.0)
- **cfg-gating:** Platform-specific code should use `#[cfg(target_os = "...")]` (timeless Rust)
- **State management:** Use `tauri::State<T>` with `Arc<Mutex<>>` for thread-safe shared state (as of Tauri 2.0)
