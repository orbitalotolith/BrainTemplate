---
tags: [reference, ios]
---
# iOS Development Notes

## SwiftUI Patterns
- `@MainActor` for UI-bound singletons (services that publish state) (Swift 5.5+, iOS 15+)
- `Task.detached {}` for CPU-heavy work (Argon2 hashing blocks UI otherwise)
- `await MainActor.run {}` to update `@MainActor` properties from detached tasks

## GRDB.swift
- `DatabaseQueue` for single-writer SQLite access
- `row["column"]` returns type inferred by call site — use optionals for nullable columns (see `sqlite-date-handling.md` for crash details)
- `Row`-based SQL queries are simpler than the Record protocol for desktop-compatible schemas

## CryptoKit
- `AES.GCM.SealedBox(combined:)` expects: nonce(12) + ciphertext + tag(16) (see `cross-platform-crypto.md` for reconstruction details)
- `HMAC<Insecure.SHA1>` for TOTP (requires iOS 16+)
- `P256.KeyAgreement` for ECDH

## Keychain (Security framework)
- `kSecClassGenericPassword` for token/key storage
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for security-sensitive data
- Always check `OSStatus` return codes

## Xcode Build Settings (as of Xcode 16)
- Bridging headers: `$(SRCROOT)/path/to/Header.h`
- Header search paths must be set for C code compiled into Swift projects
- SPM packages added via Xcode UI, not Package.swift for app targets (as of Xcode 16)

## UITextField Keyboard Handling
- `shouldChangeCharactersIn(_:range:replacementString:)` is NOT called when the text field is empty and the user presses delete (as of iOS 17). The only reliable hook is overriding `deleteBackward()` in a `UITextField` subclass.
- Pattern for hidden keyboard input capture: always clear field text on next run loop (`DispatchQueue.main.async { textField.text = "" }`). This keeps the field empty for reliable next-character capture and keeps keyboard shift/caps state updating naturally. But it means delete must go through `deleteBackward()`.
- `autocapitalizationType = .none` prevents auto-caps but NOT manual caps lock (double-tap shift). Caps lock is iOS keyboard state, independent of text field content.

## Swift Concurrency (as of Swift 5.10)
- `AsyncStream.Continuation.finish()` permanently closes the stream — the stream cannot be reused after `finish()`. Create a new `AsyncStream` instance for each use cycle (e.g., per network connection).
- `withCheckedContinuation` does NOT resume automatically on scope exit. If the function that stores the continuation exits without calling `resume()`, the awaiting caller hangs indefinitely and emits a "SWIFT TASK CONTINUATION MISUSE" warning at dealloc.
- Xcode incremental builds can hide actor-isolation compile errors. A `xcodegen generate` or `xcodebuild clean` that forces a full rebuild will expose them. Always do a clean build before TestFlight archive.
- `@MainActor` classes using `UIDevice.current.name` are safe; non-`@MainActor` callers get a Swift 6 warning since `UIDevice` properties are main-actor-isolated.
- **Timeout pattern:** Never use two competing Tasks to implement a timeout with `withCheckedContinuation` — both can resume the continuation, causing a runtime crash. Use `withTaskGroup` instead: first result wins, `cancelAll()` stops the other. (as of Swift 5.10)
- **`@Sendable` closures** cannot capture mutable local variables. Workaround: wrap in a reference type — `final class Counter: @unchecked Sendable { var value = 0 }`. Safe when access is sequential (e.g., async handshake steps).

## TestFlight Deployment (as of Xcode 16)

### Xcode Signing with xcodegen
- Don't set `CODE_SIGN_IDENTITY` explicitly with `CODE_SIGN_STYLE: Automatic` — causes archive failures
- Only need: `DEVELOPMENT_TEAM` + `CODE_SIGN_STYLE: Automatic` + `CODE_SIGN_ENTITLEMENTS`
- After any signing changes, run `xcodegen generate` before building

### Device Registration
- First `xcodebuild archive` fails with "Your team has no devices" if no iOS device registered
- Fix: install on physical device via Xcode (Cmd+R) first to auto-register

### Archive from CLI
```bash
xcodebuild -project MyApp.xcodeproj -scheme MyApp -sdk iphoneos \
  -configuration Release -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates archive -archivePath build/MyApp.xcarchive
```
- Upload via Xcode Organizer: Window > Organizer > Distribute App > TestFlight

### App Icon
- TestFlight requires app icon; iOS 17+ needs only single 1024x1024 PNG:
```
Assets.xcassets/
  Contents.json
  AppIcon.appiconset/
    Contents.json  (idiom=universal, platform=ios, references icon-1024.png)
    icon-1024.png
```

### App Store Connect
- Must create app in App Store Connect with correct bundle ID before uploading — manual step, can't automate from CLI

## SwiftData (as of iOS 18)
- SwiftData stores `@Model` classes as CoreData tables in a SQLite file (`default.store` in Application Support). Entity `Foo` → table `ZFOO`, attribute `bar` → column `ZBAR`.
- SwiftData asserts that enum raw values from stored data are valid before calling `Decodable.init(from:)`. If a stored raw value doesn't match any enum case, the app crashes with `EXC_BREAKPOINT` in `ManagedObjectKeyedDecoding.getAttribute`. Overriding `init(from:)` does NOT prevent this crash.
- **Workaround for raw value migration**: Patch the SQLite store directly via `SQLite3` in `App.init()` BEFORE creating `ModelContainer`. Example: `sqlite3_exec(db, "UPDATE ZFOO SET ZBAR = 'newValue' WHERE ZBAR = 'oldValue'", nil, nil, nil)`. No-op if file doesn't exist (fresh install).
- Add `libsqlite3.tbd` to your Xcode target dependencies to use `SQLite3` from Swift.
- **Non-optional Bool migration crash**: Adding a non-optional `Bool` property (e.g. `var flag: Bool`) to an existing `@Model` without a default value causes the store migration to fail silently, crashing the app on next launch. Fix: catch the migration error in `App.init()`, delete the store files (`.store`, `.store-shm`, `.store-wal`), and recreate the container. Safer long-term: give new non-optional properties a default value in the initializer.
- Xcode crash logs for TestFlight apps sync to `~/Library/Developer/Xcode/Products/<bundle-id>/Crashes/` when the device is connected to a Mac running Xcode.

## SwiftUI Sheets (as of iOS 17)
- **Nested-sheet dismiss resolves to wrong ancestor**: `@Environment(\.dismiss)` inside a sheet resolves to the nearest ancestor sheet presentation, not the current one. If a child view's `.sheet(isPresented:)` is attached inside a `Form` or `List` within a parent sheet, calling `dismiss()` dismisses the parent sheet (goes back to home screen) instead of the child sheet. Fix: always attach `.sheet(isPresented:)` at the `NavigationStack` level of the parent, not inside subviews.
- **Nested NavigationStack crash (iOS 17+)**: Presenting a view inside a sheet that already has a `NavigationStack` while the sheet itself is wrapped in another `NavigationStack` causes a crash. Never wrap sheet content in a second `NavigationStack` if the presented view already provides its own.

## VisionKit / DataScannerViewController (as of iOS 17)
- `DataScannerViewController.isSupported` = hardware capability (stable). `isAvailable` = hardware + camera permission granted (dynamic). Use `isSupported` for deciding whether to show scanner UI; `isAvailable` only tells you if scanning will actually work right now.
- Camera permission must be requested BEFORE `isAvailable` returns true — chicken-and-egg problem. Either pre-warm permission elsewhere or show the scanner UI based on `isSupported` and handle permission inside.
- `qualityLevel: .fast` + `isHighFrameRateTrackingEnabled: false` gives snappier startup and lower battery use for single-scan use cases.
- `.navigationBarHidden(true)` is deprecated and non-functional in iOS 16+. Use `.toolbar(.hidden, for: .navigationBar)` instead.

## SwiftUI .disabled() Gotcha (as of iOS 17)
- `.disabled({ ... }())` with an immediately-invoked closure evaluates ONCE at view creation time — it is NOT reactive. If the closure reads `@State` or `@Observable` values, changes to those values will NOT re-evaluate the disabled state. Use inline expressions: `.disabled(someCondition)` or `.disabled(Decimal(string: amount) == nil)`.

## Memory Safety
- Swift has no `zeroize` equivalent in stdlib (as of Swift 5.10; check for updates) — set `SymmetricKey` to nil on logout as best-effort cleanup

## UIViewRepresentable for Multi-Touch (as of iOS 17)
- SwiftUI gestures lack tap location and multi-touch — use `UIViewRepresentable` wrapping a `UIView` with UIKit gesture recognizers for remote desktop, drawing, or custom touch-handling scenarios
- Hidden `UIKeyInput` view as first responder for keyboard input capture in custom views — map characters to platform key codes via a lookup table, send key_down + key_up pairs per character
- Coordinate mapping for aspect-fit content: `desktopX = ((touchX - fitRect.minX) / fitRect.width) * desktopWidth` — calculate the aspect-fit rect of content within view bounds, then map touch coordinates relative to fit rect

## AVFoundation Audio (as of macOS 15 / iOS 18)
- **`AVAudioFormat(streamDescription:)` for kAudioFormatMPEG4AAC is incomplete**: A bare `AudioStreamBasicDescription` with `mFormatID = kAudioFormatMPEG4AAC` creates an `AVAudioConverter` with `maximumOutputPacketSize = 0`. `AVAudioCompressedBuffer` allocated with `maximumPacketSize: 0` has 0 bytes, and every `convert()` call produces `byteLength = 0` with `error = nil`. Use `AVAudioFormat(settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100.0, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 128_000])` instead.
- **`AVAudioEngine.outputNode.outputFormat(forBus:0)` returns `{0 Hz, 0ch}` before engine start**: Using this as a PCM buffer format gives `frameCapacity = 1024 * (0/44100) = 0`; `AVAudioPCMBuffer(pcmFormat:frameCapacity:0)` returns nil; every decode silently fails. Use `AVAudioFormat(standardFormatWithSampleRate:44100, channels:2)` — a fixed standard format; AVAudioEngine handles hardware resampling internally.
- **`AVAudioEngine.outputNode.installTap()` crashes on macOS 15 with `_isInput` assertion**: `CreateRecordingTap` internally calls `SetOutputFormat` which has an `_isInput` guard. The output node is not an input IO device. Use ScreenCaptureKit `capturesAudio = true` on `SCStreamConfiguration` instead — captures system audio without mic entitlement.
- **`AsyncStream` is permanently dead after `finish()`**: Every `yield()` after `finish()` is a silent no-op; every `for await` on the stream exits immediately. Any service that calls `stop()` (which calls `continuation.finish()`) must recreate the stream in its `start()`/`startEncoding()` method before yielding — not just reset the continuation pointer.

## Gotchas
- **iOS simulator can reach localhost; real device cannot** — use LAN IP (`ifconfig en0 | grep "inet "`) for device testing against local servers. Relay/server must bind to `0.0.0.0` (not `127.0.0.1`) to accept network connections. (not version-specific)
- **NSAllowsLocalNetworking** — iOS requires `NSAllowsLocalNetworking = true` in Info.plist's `NSAppTransportSecurity` to allow plain `ws://` connections to local network servers during development. (not version-specific)
- `ISO8601DateFormatter` produces different format than SQLite `CURRENT_TIMESTAMP` — see `sqlite-date-handling.md` for details and fix (not version-specific)
- Argon2 SPM packages broken in Xcode 16+ — embed C source directly (as of Xcode 16.2; check if resolved before working around)
- `opt.c` in Argon2 reference has x86 SIMD — replace with reference impl for ARM (see `cross-platform-crypto.md` for details)
- Simulator vs device: "invalid signature" on install means Xcode built for `Debug-iphonesimulator` — select physical device in destination picker (not version-specific)
- `rmp_serde` serializes `Vec<u8>` as msgpack array of integers, not binary — Swift decoder must handle both `bin` and `fixarray`/`array16` formats (as of rmp-serde 1.x)
- `rmp_serde` positional array deserialization is fragile with `Option` fields across Swift ↔ Rust boundary — `nil as Any?` in Swift vs `#[serde(default)] Option<String>` in Rust fails silently. Use `rmpv::Value` manual parsing instead for cross-language msgpack messages with optional fields. (as of rmp-serde 1.x)
- **Rust enum cross-language serialization**: `rmp_serde` serializes Rust enums as maps (`{"VariantName": null}`) — simpler to use String-based event types for cross-language compat with Swift/JS (as of rmp-serde 1.x)
- **Swift 6 strict concurrency incompatible with HealthKit**: HealthKit types (`HKQuantitySample`, `HKStatisticsCollectionQuery`, etc.) are non-Sendable — Swift 6 language mode produces hundreds of errors. Use Swift 5 language mode until Apple updates HealthKit for Sendable conformance. (as of Xcode 16 / iOS 18)
- **SwiftData `DataStore` naming collision**: SwiftData has a built-in `DataStore` protocol — naming your own type `DataStore` causes ambiguous type resolution. Use a prefixed name like `HealthDataStore`. (as of iOS 17+)
- **Actors cannot conform to `Observable`**: Use custom `EnvironmentKey` pattern for dependency injection when services are actors. Inject via `.environment()` modifier and read with `@Environment`. (as of Swift 5.10)
- **`withUnsafeBytes` dangling pointers**: Pointers from `Data.withUnsafeBytes` are ONLY valid inside the closure. Returning and using later = use-after-free. When a CoreMedia/VideoToolbox API needs pointers from multiple Data objects simultaneously (e.g., `CMVideoFormatDescriptionCreateFromH264ParameterSets`), nest the `withUnsafe*` calls so all pointers are live when the API runs. (not version-specific)
- Env vars passed to background processes (`VAR=x command &`) in zsh can be unreliable — for dev servers needing shared secrets, hardcode in debug builds or have server print its own token at startup (zsh-specific)
- **`GKTurnBasedMatch.endMatchInTurn` rejects already-finished participants**: Setting `matchOutcome` on a participant whose `matchOutcome != .none` causes the API call to throw. Always guard with `where participant.matchOutcome == .none`. (as of iOS 17+, GameKit turn-based)
- **`GKTurnBasedMatch.loadMatches()` has async overload on iOS 17+**: The completion-handler form still exists; the `try await` form is available without wrapping on iOS 17+ via Swift concurrency overlay. (as of iOS 17)
- **Real-time GKMatch and turn-based GKTurnBasedMatch coexist independently**: `GKLocalPlayer.local.register(_:)` for turn-based event listener does not interfere with GKMatchDelegate for real-time matches. Register separately after authentication. (not version-specific)
