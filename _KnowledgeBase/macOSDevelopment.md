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

### FDA responsibility chain uses `__CFBundleIdentifier` (as of macOS Sequoia 15 / Tahoe 26)
**Symptom:** Same as the symlink gotcha — `authorization denied` on `~/Library/Messages/chat.db` even after granting FDA to every plausible Python binary.

**Root cause:** macOS TCC doesn't just look at the binary. For ad-hoc-signed / Framework-bundled binaries (e.g. a Homebrew Python), TCC falls back to the **"responsible process"** — determined by the `__CFBundleIdentifier` env var that macOS sets when a process is spawned by a `.app` bundle. Children inherit this env var through shell → subprocess chains. So a Python launched from a Claude Code shell has `__CFBundleIdentifier=com.anthropic.claudefordesktop` and TCC checks Claude.app's FDA grant. A Python launched by a Swift app via `Process()` inherits the Swift app's bundle identifier.

**Practical implication:** granting FDA to `.venv/bin/python` is useless when the process is spawned from a .app bundle — the resolution chain ignores the binary entirely and goes to the parent bundle. The user must grant FDA to the actual parent bundle (Terminal.app / Claude.app / YourApp.app).

**How to verify the responsibility chain:**
```bash
# In the shell/process chain in question, check the env var
python3 -c 'import os; print(os.environ.get("__CFBundleIdentifier", "<unset>"))'
```

**How to detect the parent bundle in Python:** walk up from `sys.executable` looking for a `.app` suffix, BUT only trust the result when `__CFBundleIdentifier` is set (indicating the process was actually spawned from a .app). If unset, you're running from a plain TTY and the binary itself is the TCC grantee.

**UI guidance pattern:** surface the detected parent bundle in error messages (not just the binary path), so the user knows *which app* to find in System Settings → Privacy → Full Disk Access. The bundle identifier → display name mapping is visible via `mdfind "kMDItemCFBundleIdentifier == '<bundle-id>'"` or `NSBundle(identifier:)`.

### chat.db access
- `~/Library/Messages/chat.db` requires FDA
- Open read-only with `sqlite3.connect("file:...?mode=ro", uri=True)` to avoid locking the live DB
- WAL mode: the DB uses WAL; read-only connections handle this automatically
- Schema: `message` table, `chat` table, `chat_message_join` join table, `handle` table for sender info
- `is_from_me = 0` filters to received messages only

### AppleScript-sent iMessages land in `attributedBody`, NOT `text`
**As of:** macOS Sequoia 15

Messages sent via `osascript`/AppleScript (e.g. via the Messages.app "tell application" bridge) store their body as an NSKeyedArchiver blob in the `message.attributedBody` column — the plain `text` column stays NULL. Any `SELECT m.text FROM message m` query will NOT see those sent messages. Consequence: a polling monitor that queries `m.text` and also sends via AppleScript cannot see its own sent messages in its own poll (easy source of "why isn't it detecting a reply to its own message" confusion).

Workarounds:
- Parse `attributedBody` via NSKeyedUnarchiver (Objective-C bridge / `pyobjc-NSKeyedArchiver`) to recover the text.
- Track sent-message rowids separately at send time and skip them on poll.
- Or send via a path that writes to `text` (there are some but they're messier — the attributedBody route is dominant on modern macOS).

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

## Process Lifecycle

- **Swift app SIGTERM does NOT cascade to its spawned child processes** (as of macOS Sequoia 15): when a Swift `Process` is launched and then the parent SwiftUI app receives SIGTERM (cmd-Q, Force Quit, etc.), the parent dies but the child reparents to `launchd` (ppid=1) and keeps running — there's no process-group reaper unless you install one. If clean shutdown matters for a launched CLI/daemon (Python backend, native helper), SIGTERM the child pid explicitly from the parent's shutdown handler. Observed empirically: parent killed at pid X, children at X+1 / X+2 survived with ppid=1; had to `kill` them manually. Fix pattern: track child pids, install a signal handler on the parent, forward SIGTERM before exiting.

## Swift Process and External Binaries

- **Swift `Process` fails on relative symlinks in `executableURL`** (as of Swift 5.9+/macOS 14+): If `executableURL` points to a symlink whose target is a relative path (e.g. `.venv/bin/python` → `python3.14`), `Process.run()` throws `NSFileNoSuchFileError` — it can't resolve the relative target. **Fix:** Use `/usr/bin/env` as the executable and pass the symlinked binary as the first argument: `proc.executableURL = URL(fileURLWithPath: "/usr/bin/env"); proc.arguments = [venvPython.path, "main.py"]`.
- **Do NOT use `.resolvingSymlinksInPath()` on Python venv paths**: Resolving symlinks on `.venv/bin/python` produces the system Python binary (e.g. `/opt/homebrew/.../python3.14`), which bypasses the venv entirely — `sys.prefix` won't point to the venv, and site-packages won't be found. The venv relies on the binary being invoked from within `.venv/bin/` so Python startup finds `pyvenv.cfg`.
- **Xcode app sandbox blocks executing external binaries** (as of Xcode 16): `com.apple.security.app-sandbox = true` prevents `Process` from launching binaries outside the app bundle (e.g. `.venv/bin/python`, `/usr/bin/env`). Error: "operation not permitted". Set to `false` in the entitlements file for dev tools that need to spawn external processes. Not applicable to App Store apps — those need sandbox.

## SwiftPM GUI apps via `swift run`

- **`swift run` GUI apps land in accessory mode by default** (as of Swift 5.9+/macOS 14+): SwiftPM-produced binaries have no Info.plist, so macOS treats them as CLI tools. SwiftUI window appears but the process is an "accessory" — no keyboard focus, no Dock icon, no cmd-tab, top-left menu bar keeps showing the previous frontmost app. **Fix:** Call `NSApplication.shared.setActivationPolicy(.regular)` and `NSApplication.shared.activate(ignoringOtherApps: true)` in the `@main App` struct's `init()`. Requires `import AppKit`. Runs before SwiftUI's scene body. Alternative is to build a proper `.app` bundle via Xcode or a future SwiftPM plugin — but the runtime call is one line and works from `swift run` directly.
- **`#filePath`-based repo discovery is fragile with parallel worktrees**: If your Swift app walks up from `#filePath` looking for a sentinel file (e.g. `main.py`, `Package.swift`), it finds the sentinel in whichever source tree the binary was built from — NOT necessarily the tree the user is "in." When two checkouts of the same repo (main + worktree) share directory structure, launching `swift run` from the wrong `clients/macos/` silently runs the whole stack from the wrong branch. Symptom: backend serves an older API shape (404s on newer routes) even though git/pwd looks right. Diagnose by: `lsof -a -d cwd -p $PID` on any child process the app spawns. Mitigation: embed a build-time marker (envvar, generated file), or echo the resolved root on app startup so users see it before debugging.
- **`print()` from `swift run` windowed apps is unreliable** (as of Swift 5.9 / macOS 14): stdout buffering loses output once `NSApplicationMain` starts the run loop. `swift run | tee /tmp/log` captures build output but NOT runtime `print()`. For runtime debug, write to files via `FileHandle(forWritingAtPath:)` — append mode with `seekToEndOfFile()` + `closeFile()` per event, `tail -f` or `grep` works cleanly. Reliable and loss-free.

## SwiftUI NavigationStack

- **macOS NavigationStack does NOT fire `.onAppear`/`.onDisappear` on back-stack views** (as of macOS 14 / SwiftUI 5): When a new view is pushed on top of the current one via `NavigationLink(value:)`, the previously-visible view stays "present" — no `.onDisappear` fires. On pop-back, the revealed view gets NO `.onAppear`. Only the top-of-stack view transitions. This differs from common iOS mental models. **Implication:** Don't rely on `.onAppear` to refresh a pushed detail view's data when the user pops back to it. Confirmed empirically via file-based logging: 3 pushes = 3 `.onAppear` events; 1 back press = 1 `.onDisappear` (top only), no `.onAppear` on the revealed view below. **Pattern that works:** each pushed view owns its own `@State` detail and fetches via `.task(id: propertyKey)` on mount; avoid sharing mutable slots across stack entries in a cross-cutting observable object. If you MUST share state, bind an explicit `NavigationPath` and use `.onChange(of: path)` at the root to detect pop events and refresh the revealed view.
- **`.task(id:)` reruns on id change, fires only once per view instance otherwise** — useful when SwiftUI reuses an AgentDetailView (or similar) at the same structural position with a different property value. Plain `.task` is equivalent to `.onAppear` + async wrap.

## SwiftUI Markdown Rendering

- **`AttributedString(markdown:)` is inline-only** — even with `.init(interpretedSyntax: .full)`. Block elements (`#` headings, `-`/`*` bullets, blank-line paragraphs, code blocks, tables) pass through as literal text. Only inline syntax works out of the box: `**bold**`, `*italic*`, `` `code` ``, `[links](url)`. For block-level markdown rendering in a read-only view, either (a) add a third-party lib like [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui), or (b) write a ~50-line line-splitter that maps `^#{1,6}\s+` → heading fonts (`.title`, `.title2`, `.title3`), `^\s*[-*]\s+` → bullets, blank lines → spacers, and still runs each non-empty line through `AttributedString(markdown:)` for inline syntax. Option (b) handles most real-world blueprint/README content without a dep; Option (a) is cleaner if editing or nested lists/tables matter. (as of macOS 14 / Swift 5.9)
- **`let body: String` clashes with `View`'s `var body`** — don't name a View's input property `body`. Compiler errors as `invalid redeclaration of 'body'`. Rename to `source` / `text` / `content`. (SwiftUI)

## Xcode Command Line Tools

- **`xcode-select` must point to Xcode.app, not CommandLineTools, for `swift test` to find XCTest** (as of Xcode 16): When `/usr/bin/xcode-select -p` returns `/Library/Developer/CommandLineTools`, `swift test` fails with missing XCTest framework errors. The CLT distribution doesn't ship XCTest; it's in the full Xcode.app bundle. Fix: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`. Verify with `xcrun --find xctest` — should print a path inside Xcode.app, not CLT.

## Keychain CLI

- **`security add-generic-password` exposes the password in the process list** (as of macOS Sequoia 15): The `-w <password>` flag is visible to any process that can run `ps` during the ~1ms the command is in flight. No stdin input mode exists for `add-generic-password` — you can't avoid it by piping. Acceptable for non-interactive setup scripts where the host is trusted; unacceptable for multi-user or hostile-local environments. For code writing secrets programmatically, use the Security Framework APIs (`SecItemAdd` / `SecItemUpdate`) rather than shelling to `security`.

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
- **`JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` runs BEFORE CodingKey rawValue matching**: The decoder converts snake_case JSON keys to camelCase first, then matches against your type's CodingKeys. So a CodingKey declared as `case displayName = "display_name"` will FAIL to match — by the time lookup happens, the wire key has already been transformed to `displayName`. CodingKeys must be camelCase only: either synthesized (omit the `enum CodingKeys`) or explicit cases without rawValue override (`case displayName, contentHash, ...`). The strategy does NOT recurse into `[String: T]` value types decoded via `singleValueContainer()` (e.g. `AnyCodable`) — nested dict keys stay verbatim. Per Apple docs and verified empirically (Swift 5.9 / macOS 14).
- **`URL.appendingPathComponent` double-encodes `%` and drops query strings**: `baseURL.appendingPathComponent("/memory/%2B15551234567/...")` produces `baseURL/memory/%252B15551234567/...` (the `%` re-encodes to `%25`, so the server sees the literal `%2B` string instead of decoding to `+`). Similarly `"/path/key/history?limit=50"` → `?` encodes to `%3F`, absorbed into the path, query never reaches the server (`URLComponents.query` returns `nil`). This bug is latent in any caller that passes hardcoded UUID/slug paths (never encoded) but triggers immediately for pre-encoded segments or query strings. **Fix:** concatenate instead — `URL(string: baseURL.absoluteString.trimmingTrailing("/") + path)!`. A `fullURL(for:)` helper on the API client keeps this in one place. Also covered: `URL(string: path, relativeTo: baseURL)?.absoluteURL` behaves correctly per RFC 3986. (as of Foundation on macOS 14+)
- **`AnyCodable.encode(to:)` is round-trip asymmetric for nested types**: A common `AnyCodable` (or `AnyJSON`) struct typically decodes via `singleValueContainer` and unwraps Bool/Int/Double/String/dict/array/null into `Any`. But the encoder side often only covers primitives — falling through to `container.encodeNil()` for `[String: Any]`, `[Any]`, `NSNull`. Round-tripping a nested dict like `{"properties": {"path": {"type": "string"}}}` through `JSONEncoder.encode([String: AnyCodable].self, ...)` silently produces `{"properties": null}`. **Fix for display-time rendering:** unwrap to bare types via `dict.mapValues { $0.value }` and use `JSONSerialization.data(withJSONObject:options: [.prettyPrinted, .sortedKeys])` — it handles dicts/arrays/NSNull natively without needing `Codable` conformance. **Long-term fix:** add explicit `[String: Any]` / `[Any]` / `NSNull` cases to `AnyCodable.encode` (recursively re-wrap when needed). (Swift 5.9 / Foundation)
