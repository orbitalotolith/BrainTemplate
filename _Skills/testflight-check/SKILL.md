---
name: testflight-check
description: Audit an iOS/macOS app project for TestFlight readiness before archiving. Catches sandbox violations, entitlement mismatches, signing conflicts, missing Info.plist keys, stale Rust FFI binaries, hardcoded paths, icon requirements, and relay deployment issues that cause crashes or rejections in sandboxed TestFlight builds. Use when the user mentions TestFlight, archiving, uploading to App Store Connect, beta testing, or preparing a build for distribution. Also trigger on "ready for TestFlight", "archive the app", "submit to TestFlight", or "pre-flight check".
user-invocable: true
disable-model-invocation: true
allowed-tools: Agent, Bash, Glob, Grep, Read
---

# TestFlight Check

Audit an app project before archiving for TestFlight. TestFlight builds run in a real sandbox with real code signing — many issues only surface after archive+upload, never in debug builds. This skill catches them before you waste a round trip.

## Overview

[TBD]

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### Workflow

#### 1. Detect Targets & Stack

Use the **Glob** tool to scan the project root and determine what's in play:

| Marker | Detected Component |
|--------|--------------------|
| `project.yml` or `*.xcodeproj` | App targets — parse for iOS and/or macOS |
| `Cargo.toml` with `staticlib` | Rust FFI in use |
| Bridging header (`*-Bridging-Header.h`) | Confirms Rust/C FFI integration |
| `Dockerfile` + `fly.toml` | Relay/backend deployment |
| `rmp-serde` in Cargo.toml + `MsgPack` in Swift | Cross-language msgpack |

Determine which audit sections apply. Report detected targets before proceeding.

#### 2. Audit

Use the **Agent** tool to launch up to 3 explore agents in parallel, distributing these sections across them for speed. Skip sections that don't apply.

##### A. Signing Configuration

Parse `project.yml` (or xcodeproj build settings) for each target:

- **BLOCK** if `CODE_SIGN_IDENTITY` is set alongside `CODE_SIGN_STYLE: Automatic` — these conflict and cause archive failures. Fix: remove `CODE_SIGN_IDENTITY`, keep only `DEVELOPMENT_TEAM` + `CODE_SIGN_STYLE: Automatic`.
- **BLOCK** if `DEVELOPMENT_TEAM` is missing for any target.
- **BLOCK** if `PROVISIONING_PROFILE_SPECIFIER` is set with Automatic signing.
- **WARN** if `CODE_SIGN_ENTITLEMENTS` path points to a file that does not exist.

##### B. Entitlements vs Code Usage

Parse each target's `.entitlements` file. Grep Swift/ObjC/Rust sources for API usage and cross-reference:

| API Pattern | Required Entitlement |
|-------------|---------------------|
| `ScreenCaptureKit`, `SCStream`, `SCShareableContent`, `CGDisplayStream` | `com.apple.security.screen-recording` |
| `NWConnection`, `NWListener`, `URLSession`, `WebSocket` | `com.apple.security.network.client` and/or `.server` |
| `AXIsProcessTrusted`, `AXUIElement`, `CGEvent` | Accessibility (temporary exception or TCC) |
| `SecItem`, `Keychain` | `keychain-access-groups` |
| `UNUserNotificationCenter` (remote) | Push notification entitlement |

- **BLOCK** if code uses a capability but the entitlement is missing.
- **WARN** if an entitlement is declared but no corresponding code usage is found (unnecessary entitlements trigger App Review questions).

##### C. Info.plist Requirements

**macOS targets:**
- **BLOCK** if missing `CFBundleExecutable`.
- **BLOCK** if missing `CFBundlePackageType` or value is not `APPL`.
- **BLOCK** if missing `LSApplicationCategoryType`.
- **BLOCK** if missing `CFBundleShortVersionString` or `CFBundleVersion`.
- **WARN** if `CFBundleVersion` is not a monotonically increasing integer (App Store Connect rejects reused build numbers).
- **BLOCK** if no ICNS icon with 512@2x (1024x1024) — check asset catalog `*.appiconset`.

**iOS targets:**
- **BLOCK** if missing `CFBundleExecutable`.
- **BLOCK** if `UILaunchScreen` or `UILaunchStoryboardName` is missing.
- **BLOCK** if no 1024x1024 app icon PNG in `AppIcon.appiconset`.

**Both platforms:**
- **BLOCK** if `CFBundleShortVersionString` is not semver format (`X.Y.Z`).
- **BLOCK** if a capability is used but the corresponding `NS*UsageDescription` key is missing:

| Capability | Required Info.plist Key |
|-----------|------------------------|
| Screen recording | `NSScreenCaptureUsageDescription` |
| Camera | `NSCameraUsageDescription` |
| Microphone | `NSMicrophoneUsageDescription` |
| Face ID | `NSFaceIDUsageDescription` |
| Local network | `NSLocalNetworkUsageDescription` |
| Apple Events | `NSAppleEventsUsageDescription` |

##### D. Sandbox Safety (macOS only, when `com.apple.security.app-sandbox` is true)

**Hardcoded paths that break in sandbox — grep all app sources:**
- `~/.config/`, `~/.local/`, `~/Library/` used directly (not via `FileManager`)
- `NSHomeDirectory()` used for file storage
- `ProcessInfo.processInfo.environment["HOME"]`
- In Rust: `dirs::config_dir()`, `dirs::data_dir()`, `dirs::home_dir()`, `std::env::home_dir()` without a `set_state_dir` override

**BLOCK** if any hardcoded paths are found in app target sources.

**Init ordering (when Rust FFI is used):**
- Verify that the sandbox-safe storage directory is passed to Rust (e.g., `firetop_set_state_dir()` or equivalent) BEFORE any FFI calls that access storage (`firetop_get_device_id`, `firetop_load_keypair`, etc.).
- Check that `@State` properties creating objects that call FFI are initialized in `init()` with `State(initialValue:)` — NOT inline — to guarantee ordering.
- **BLOCK** if storage init call is missing or comes after storage-accessing FFI calls.

**Permission requests:**
- **WARN** if `CGRequestScreenCaptureAccess()` is not called before first use of `SCShareableContent` — the app may not appear in System Settings' Screen Recording list.

##### E. Rust FFI (when staticlib crate detected)

**Universal binary:**
- Check that both `aarch64-apple-darwin` and `x86_64-apple-darwin` targets are built for release.
- Check that `lipo -create` produces the universal `.a` at the path referenced by `LIBRARY_SEARCH_PATHS`.
- **BLOCK** if only one architecture exists in the release `.a` (run `lipo -info` on it).

**Library freshness:**
- Compare mtime of `target/release/lib*.a` against newest `.rs` file in the crate's `src/`.
- **WARN** if the `.a` is older than any `.rs` source — stale binary causes `EXC_BAD_ACCESS` from struct layout mismatch.

**C header freshness:**
- If `cbindgen.toml` exists, count `#[no_mangle] pub extern "C" fn` declarations in Rust source and compare against function declarations in the `.h` file.
- **BLOCK** if counts differ — the header is stale and Swift won't see new FFI functions.

**FFmpeg dependency (if `ffmpeg-next` in Cargo.toml):**
- **WARN** to verify FFmpeg 7 is installed, not FFmpeg 8. Check `PKG_CONFIG_PATH` in build scripts for `ffmpeg@7`.
- **BLOCK** if `ffmpeg@8` path is detected (FFmpeg 8 removed `avfft.h`).

##### F. msgpack Compatibility (when rmp-serde + Swift MsgPack detected)

- **WARN** about `rmp_serde` serializing `Vec<u8>` as array of integers, not binary. Verify Swift decoders handle both formats.
- **WARN** if any Rust struct uses `#[serde(skip_serializing_if)]` on fields sent cross-language — shifts positional array indices when None.
- **WARN** to verify Rust struct field ORDER matches Swift decode order (rmp_serde positional arrays).

##### G. Relay/Backend Deployment (when Dockerfile + fly.toml exist)

**Dockerfile:**
- **BLOCK** if runtime stage uses `debian:*-slim` or `ubuntu:*` instead of `rust:latest` — glibc mismatch crashes the binary.

**fly.toml:**
- **BLOCK** if using `[[services]]` instead of `[http_service]` — WebSocket routing breaks silently.
- **BLOCK** if `auto_stop_machines` is not `"off"` for always-on WebSocket services.
- **WARN** if `force_https` is not `true`.

**URL consistency:**
- Grep app Swift sources for relay URLs and compare against `app` name in fly.toml. **WARN** if they don't match.

##### H. Compile Check

After all static audits, use the **Bash** tool to run a release build for each detected app target to catch compiler errors (type mismatches, missing scope, etc.) that only surface at build time:

```bash
xcodebuild -project *.xcodeproj -scheme <scheme> -configuration Release build CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO 2>&1 | tail -50
```

- Use `CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO` to skip signing (we only care about compilation).
- **BLOCK** on any compile error. Include the error message and file path in the report.
- If `project.yml` exists, run `xcodegen generate` first to ensure the project file is fresh.

#### 3. Report

Compile findings into a readiness report:

```
## TestFlight Check: [project name]

### Verdict
[Ready for TestFlight / Needs fixes / Not ready]

### Targets Detected
| Target | Platform | Rust FFI | Sandbox | Relay |
|--------|----------|----------|---------|-------|
| ...    | ...      | Yes/No   | Yes/No  | Yes/No|

### BLOCK (N issues)
- [ ] [TF-001] Issue — path and details
  → Fix: `command or instruction`

### WARN (N issues)
- [ ] [TF-010] Issue — path and details
  → Fix: `command or instruction`

### Passed
- [x] Category — what was checked and passed
```

#### 4. Pre-Archive Commands

If any BLOCK issues exist, provide a sequenced fix script the user can review and run. Group by category:

```bash
# Rust library rebuild
PKG_CONFIG_PATH="..." cargo build -p <crate> --release --target aarch64-apple-darwin
PKG_CONFIG_PATH="..." cargo build -p <crate> --release --target x86_64-apple-darwin
lipo -create <arm64.a> <x86_64.a> -output <universal.a>

# Header regeneration
cbindgen --config cbindgen.toml --crate <crate> --output <header.h>

# Info.plist fixes
/usr/libexec/PlistBuddy -c "Add :LSApplicationCategoryType string public.app-category.utilities" path/Info.plist

# Entitlement additions (manual — edit the .entitlements XML)
```

## Output

[TBD]

## Rules

### Edge Cases

- **SwiftUI-only app (no Rust FFI)**: Skip sections D (sandbox storage init), E (Rust FFI), F (msgpack).
- **iOS-only project**: Skip macOS sandbox checks, ICNS icon, screen recording entitlement. Still check iOS icon, Info.plist, signing.
- **No relay/backend**: Skip section G entirely.
- **SPM-only project (no xcodegen)**: Look for `.xcodeproj` build settings directly instead of `project.yml`.
- **Multiple app targets**: Run checks independently for each target, report separately.
