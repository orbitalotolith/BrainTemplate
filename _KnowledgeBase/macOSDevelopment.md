---
tags: [reference, macos]
---
# macOS Development Notes

## App Sandbox

- Sandboxed apps resolve `FileManager.default.urls(for: .applicationSupportDirectory)` to `~/Library/Containers/<bundle-id>/Data/Library/Application Support/` — NOT the shared `~/Library/Application Support/`
- Rust `dirs::config_dir()` returns the unsandboxed path — crashes in sandboxed TestFlight/App Store builds. Must pass the sandbox-safe path from Swift via FFI before any storage operations.
- `@State` property initializers run at declaration time, potentially before `init()` body. Use `State(initialValue:)` in `init()` to guarantee ordering when setup must precede property creation.

## TCC Permissions

- **macOS 26 (Tahoe)**: "Screen & System Audio Recording" is a separate TCC category from legacy "Screen Recording". `CGPreflightScreenCaptureAccess()` and `CGRequestScreenCaptureAccess()` check/register the OLD category. Use `SCShareableContent.excludingDesktopWindows()` to check and trigger the new one. (as of macOS 26.3)
- `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` shows the system Accessibility prompt for **non-sandboxed** apps. `AXIsProcessTrusted()` only checks without prompting. **Sandboxed apps:** the prompt option silently does nothing. Instead, open System Settings directly via deep-link URLs: Accessibility `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`, Screen Recording `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`. Open via `NSWorkspace.shared.open(url)`. User must manually add the app using the `+` button. Always show "Open System Settings" link regardless of current permission status — user may want to revoke too. Show current status via `AXIsProcessTrusted()` (Accessibility) and `CGPreflightScreenCaptureAccess()` (Screen Recording). Settings sheet should have a Done/close button via `.cancellationAction` toolbar placement.
- `tccutil reset <service> <bundle-id>` wipes TCC permissions per-app. Services: `ScreenCapture`, `Accessibility`, `AppleEvents`. Useful when debug rebuilds corrupt TCC state.
- Debug builds change code signature on each rebuild — macOS may not recognize the app as previously granted. Reset TCC and re-grant after rebuilds if permissions seem stuck.

## TCC / Full Disk Access (FDA)

### FDA symlink gotcha (as of macOS Sequoia 15)
**Symptom:** `sqlite3.DatabaseError: authorization denied` when reading `~/Library/Messages/chat.db` even after granting FDA.

**Root cause:** macOS TCC records FDA grants by the *actual binary path* (after all symlink resolution), not the symlink you dragged into the FDA list. If you drag a symlink (e.g. `venv/bin/python` → `python3` → `/Library/Developer/CommandLineTools/usr/bin/python3` → Framework binary), the TCC entry stores the dragged symlink path. But at runtime, macOS checks the resolved binary — the paths don't match, so FDA is denied.

**Fix:** Grant FDA to the actual resolved binary. Run `realpath <your-symlink>` to find it, then drag that file into FDA. For Python from CommandLineTools:
```
realpath /Library/Developer/CommandLineTools/usr/bin/python3
# → /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9
```
Open that folder in Finder: `open /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/bin/`
Drag `python3.9` directly into the FDA list.

**Also:** Framework/non-app binaries appear greyed out in the FDA file picker — you can't click them. Drag-and-drop from a Finder window works even when the picker greys them out.

**launchd note:** Update your plist `ProgramArguments` to use the resolved binary path too — otherwise launchd launches the resolved binary which may not match your FDA entry.

### chat.db access
- `~/Library/Messages/chat.db` requires FDA
- Open read-only with `sqlite3.connect("file:...?mode=ro", uri=True)` to avoid locking the live DB
- WAL mode: the DB uses WAL; read-only connections handle this automatically
- Schema: `message` table, `chat` table, `chat_message_join` join table, `handle` table for sender info
- `is_from_me = 0` filters to received messages only

### tccutil limitations
- `tccutil` can only **reset** (remove) TCC permissions — it cannot grant them
- The only way to grant FDA is through the System Settings GUI
- Even with root / SIP disabled, modifying TCC.db directly is unreliable on modern macOS

## Rust + macOS Native APIs

### CGEvent Input Injection (as of core-graphics 0.24)
- `CGEvent::new_mouse_event()` / `CGEvent::new_keyboard_event()` + `.post(CGEventTapLocation::HID)`
- Scroll NOT in crate — use raw FFI: `CGEventCreateScrollWheelEvent2()` + `CGEventPost()` + `CFRelease()`
- Requires Accessibility permission — events silently fail without it
- Modifier flags: Shift `0x20000`, Control `0x40000`, Alt `0x80000`, Command `0x100000`

### Screen Capture (as of macOS Sequoia 15)
- `core-graphics` crate: `CGDisplay::main()` / `CGDisplayCreateImage()` for screenshots
- `screencapture` CLI: simplest approach, ~4-5 FPS max
- ScreenCaptureKit: best quality but complex FFI via `objc2` crates

### Keyring Storage (as of keyring 3.x)
- Cross-platform credential storage; macOS uses Keychain under the hood
- May not persist between runs depending on code signing/sandbox state — provide CLI flag fallback

## TestFlight / App Store Requirements (macOS)

- Must have: `com.apple.security.app-sandbox` entitlement, ICNS icon (512@2x = 1024x1024)
- Info.plist required keys: `CFBundleExecutable`, `CFBundlePackageType` (APPL), `LSApplicationCategoryType`, `CFBundleShortVersionString` (semver), `CFBundleVersion` (monotonically increasing integer)
- `NS*UsageDescription` keys required for each capability used (screen capture, Apple Events, local network, etc.)
- `com.apple.security.screen-recording` is NOT a valid entitlement — causes archive error 90285. Screen recording is runtime TCC only (`CGPreflightScreenCaptureAccess()` / `SCShareableContent`). No entitlement needed.
- Apple encryption export compliance: Noise XX / Curve25519 / ChaCha20-Poly1305 → select "Standard encryption algorithms"
- **PrivacyInfo.xcprivacy required for UserDefaults**: Any target using `UserDefaults`, `@AppStorage`, or `NSUserDefaults` must declare `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`. Empty or missing manifest triggers App Store Connect warnings. Add as a `resources:` entry in xcodegen's project.yml.
- **LaunchDaemons are incompatible with TestFlight and Mac App Store**: Any app bundle containing `Contents/Library/LaunchDaemons/` will not show "TestFlight & App Store" in Xcode Organizer — only "Custom" (Developer ID / direct distribution). Root-level daemons require notarized direct distribution. Apps needing pre-login or system-level access must ship via Developer ID + DMG/PKG, not TestFlight or MAS. Login items (`SMAppService.loginItem()`) and XPC services ARE permitted. (as of macOS 13+ / Xcode 15+)

## Swift Process and External Binaries

- **Swift `Process` fails on relative symlinks in `executableURL`** (as of Swift 5.9+/macOS 14+): If `executableURL` points to a symlink whose target is a relative path (e.g. `.venv/bin/python` → `python3.14`), `Process.run()` throws `NSFileNoSuchFileError` — it can't resolve the relative target. **Fix:** Use `/usr/bin/env` as the executable and pass the symlinked binary as the first argument: `proc.executableURL = URL(fileURLWithPath: "/usr/bin/env"); proc.arguments = [venvPython.path, "main.py"]`.
- **Do NOT use `.resolvingSymlinksInPath()` on Python venv paths**: Resolving symlinks on `.venv/bin/python` produces the system Python binary (e.g. `/opt/homebrew/.../python3.14`), which bypasses the venv entirely — `sys.prefix` won't point to the venv, and site-packages won't be found. The venv relies on the binary being invoked from within `.venv/bin/` so Python startup finds `pyvenv.cfg`.
- **Xcode app sandbox blocks executing external binaries** (as of Xcode 16): `com.apple.security.app-sandbox = true` prevents `Process` from launching binaries outside the app bundle (e.g. `.venv/bin/python`, `/usr/bin/env`). Error: "operation not permitted". Set to `false` in the entitlements file for dev tools that need to spawn external processes. Not applicable to App Store apps — those need sandbox.

## Gotchas
- **localhost resolves to IPv6 on macOS**: `localhost` resolves to `::1` (IPv6) but `TcpListener::bind("0.0.0.0")` is IPv4 only — connection refused. Use `127.0.0.1` explicitly when a Swift app connects to a local Rust server. (as of macOS Ventura 13+)
- macOS AirPlay Receiver occupies port 5000 (as of macOS Monterey 12+). Check `lsof -i :5000` before choosing dev server ports. ControlCenter may also use port 5001.
- **xcodegen signing conflict**: Don't set `CODE_SIGN_IDENTITY` with `CODE_SIGN_STYLE: Automatic` — causes archive failures. Use only `DEVELOPMENT_TEAM` + `CODE_SIGN_STYLE: Automatic`. (as of xcodegen 2.x)
- **Rust universal binary for archive**: Must `lipo -create` arm64 + x86_64 `.a` files for "Any Mac" archive target. Single-arch `.a` causes 500+ linker errors.
- **`CFBundleVersion` must be unique per upload**: App Store Connect rejects duplicate build numbers. Always increment before archiving.
- **Swift FFI with opaque C structs (cbindgen)**: `typedef struct Foo Foo;` → Swift imports as `OpaquePointer`. FFI functions that take `Foo *` accept `OpaquePointer?` — you CANNOT convert to `UnsafeMutablePointer<Foo>` for opaque types. Store context pointers as `OpaquePointer?` and pass directly. Also: `uintptr_t` (C) maps to `UInt` (Swift), not `Int` — cast with `UInt(data.count)`. (as of Swift 5.10 / cbindgen 0.27)
- **`CGEventTapLocation.cgHIDEventTap` renamed in macOS 26 SDK**: Use `CGEventTapLocation(rawValue: 0)!` for HID tap (works as root). rawValue 1 = session tap, rawValue 2 = annotated session tap. `.cgHIDEventTap` case name removed. (as of macOS 26 SDK / Xcode 17)
- **`kCGDisplayStreamShowCursor` / `kCGDisplayStreamMinimumFrameTime` renamed in macOS 26 SDK**: Use `CGDisplayStream.showCursor` and `CGDisplayStream.minimumFrameTime`. Old C constant names no longer compile. (as of macOS 26 SDK)
- **`IOSurfaceGetBaseAddress` returns non-optional in macOS 26 SDK**: Returns `UnsafeMutableRawPointer` — `guard let` pattern fails to compile. Call directly without optional binding. (as of macOS 26 SDK)
- **SMAppService LaunchDaemon plist must be at `Contents/Library/LaunchDaemons/`**: `SMAppService.daemon(plistName:)` looks in this exact path — NOT `Contents/Resources/`. XcodeGen's `copyFiles destination: wrapper` with `subpath: Library/LaunchDaemons` does not reliably produce this layout (tested with XcodeGen 2.45.3). Use a postBuildScript to copy the plist from Resources after each build. (as of macOS 13+ / SMAppService)
- **Signal handler closures can't call actor-isolated methods**: `DispatchSource.makeSignalSource.setEventHandler { }` closure is synchronous and nonisolated. Calling `actor.method()` directly fails to compile. Wrap in a task: `setEventHandler { Task { await actor.method() } }`. (Swift 5.10+)
- **`@MainActor` static func inherits isolation — use `nonisolated static` for pure helpers**: A `static func` on a `@MainActor @Observable` class is itself MainActor-isolated, so calling it from a non-MainActor async context (preview stubs, test fakes, background helpers) requires `await MainActor.run { }`. If the function is pure (no `self` access, no isolated state), mark it `nonisolated static` to let it be called from any isolation context without crossing actors. Typical for `slugify`, validation helpers, or format functions on view models. (Swift 5.9+)
- **`catch` binding shadows enclosing stored property named `error`**: `do { ... } catch { error = error.localizedDescription }` inside an `@Observable` class with a stored `error: String?` silently compiles but `error` refers to the catch binding, not `self.error`. Result: no assignment to the stored property. Rename the binding: `catch let err { error = err.localizedDescription }`. (Swift 5.9+)
- **SwiftUI `URLProtocol` mocks deliver POST/PUT body via `httpBodyStream`, not `httpBody`**: When a test routes `URLSession` requests through a `URLProtocol` subclass, `request.httpBody` is nil — the body is delivered as a stream. Provide a `URLRequest.bodyFromStream()` extension in test helpers that opens the stream and reads bytes. Applies to URLSession snake_case conversion assertions, multipart form testing, anywhere you need to inspect what was actually sent. (as of Foundation on macOS 14+)
