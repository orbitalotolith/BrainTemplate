---
tags: [reference, remote-desktop, architecture, networking, security]
---

# Remote Desktop Architecture

Architecture patterns and implementation lessons for building a secure remote desktop app (as of 2026-03).

## Architecture: Zero-Knowledge Relay

Relay brokers connections but NEVER sees plaintext screen data. Three components:
1. **iOS Client** — connects to relay, authenticates, requests session, receives/displays video, sends input
2. **Relay Server** — validates JWT auth, matches client↔agent, forwards opaque encrypted bytes
3. **Desktop Agent** — captures screen, encodes video, encrypts with session keys, injects input

**Key principle:** Data plane messages (video, input, handshake) use `msg_type >= 0x20` and the relay forwards without inspection. Control plane (auth, session mgmt, pairing) uses `msg_type < 0x20` and the relay processes them.

## Security Model

### E2E Encryption: Noise XX Protocol
- **Why Noise XX over WireGuard:** WireGuard is a VPN (wrong abstraction). Noise XX gives exactly the handshake + channel encryption needed, integrated into the app protocol.
- **Primitives:** Curve25519 (key exchange) + ChaCha20-Poly1305 (AEAD) + SHA256 (hash) + HKDF (key derivation)
- **Forward secrecy:** Ephemeral keys per session, destroyed on disconnect
- **Mutual auth:** Both sides verify static public keys from pairing
- **Rust:** `snow` crate (mature Noise implementation)
- **Swift:** Manual implementation using CryptoKit — no Swift Noise library exists. Implement state machine with `mixHash()`, `mixKey()`, `encryptAndHash()`, `decryptAndHash()`, `split()`
- **Nonce format:** 4 zero bytes + 8-byte LE counter = 12-byte ChaChaPoly nonce (per Noise spec Section 5.1)

### Device Pairing (Trust On First Use)
- Agent generates Curve25519 keypair, displays QR code + 6-digit PIN
- QR payload: compact JSON `{v, d, n, p, k(base64), r(relay_url), c(code)}`
- iOS scans QR → stores agent public key in Keychain, creates SwiftData PairedDevice
- Agent stores client public key in OS keyring
- Subsequent sessions verify static keys during Noise handshake

### Authentication
- JWT tokens with configurable secret (env var `<APP>_JWT_SECRET`)
- Rate limiting via `governor` crate (keyed by IP, 5 attempts/minute)
- In release builds: fail hard without JWT secret (no default fallback)
- Token expiry: 2 hours for production, configurable

### Key Storage
- iOS: Keychain only (never UserDefaults/SwiftData for secrets). Use `actor KeychainService`.
- macOS agent: OS keyring via `keyring` crate (see `macOSDevelopment.md` for keyring gotchas)
- Rust: `zeroize` crate to clear private key bytes from memory after use

## Protocol Design

### Binary Format
```
Header (8 bytes): msg_type(u8) + flags(u8) + sequence(u16 BE) + payload_length(u32 BE)
Payload: msgpack for control plane, raw bytes for data plane (video/input)
```
Add max payload length validation (100MB) to prevent OOM.

### Cross-Language Serialization (Rust ↔ Swift)
- Rust `rmp_serde` serializes structs as msgpack **arrays** (field order matters)
- Swift has no good msgpack library — write minimal `MsgPack.buildMessage()` encoder
- **Critical:** Field order in Swift array must match Rust struct field declaration order
- Enum serialization: Rust enums serialize as `{"Variant": null}` maps. Simpler to use String-based event types for cross-language compat.
- Minimal Swift msgpack format bytes needed:
  - String: `0xa0-0xbf` (fixstr), `0xd9` (str8), `0xda` (str16)
  - Bool: `0xc2` (false), `0xc3` (true)
  - Int: `0x00-0x7f` (positive fixint), `0xcc` (uint8), `0xcd` (uint16), `0xcf` (uint64)
  - Float64: `0xcb` + 8 bytes IEEE 754 big-endian
  - Array: `0x90-0x9f` (fixarray), `0xdc` (array16)
  - Binary: `0xc4` (bin8), `0xc5` (bin16)
  - Nil: `0xc0`

### Cargo Workspace with Shared Proto Crate
- Create `<app>-proto/` crate for shared types between relay and agent
- Add to workspace `members` array in root `Cargo.toml`
- Reference as `<app>-proto = { path = "../<app>-proto" }` in dependent crates
- Use `pub` on all shared items

## Screen Capture

For macOS-specific capture APIs and Rust bindings, see [macOSDevelopment.md](macOSDevelopment.md#rust--macos-native-apis).

### macOS Options (ranked by quality)
1. **ScreenCaptureKit** — best (native, low latency, hardware accelerated). Requires macOS 12.3+. Complex Rust FFI.
2. **CGDisplayCreateImage** — via `core-graphics` crate. Simple but slow. Good for prototyping.
3. **`screencapture` CLI** — simplest (no FFI). ~4.5 FPS JPEG.

### Encoding Options
- **JPEG via screencapture CLI** — simple demo approach, no deps needed
- **H.264 via VideoToolbox** — production approach. Hardware accelerated on Mac. Complex Rust FFI via `objc2` crates.
- **H.264 via ffmpeg-next** — portable but requires `brew install ffmpeg pkg-config`
- iOS decoding: `VTDecompressionSession` for H.264, or `UIImage(data:)` for JPEG

## iOS Remote Desktop UI Patterns

### Gesture Mapping
- Use `UIViewRepresentable` with UIKit gesture recognizers (SwiftUI gestures lack tap location + multi-touch)
- Single tap → click (left or right based on toolbar mode)
- Double tap → double click
- 1-finger pan → mouse move
- 2-finger pan → scroll
- Bottom toolbar with Left Click / Right Click / Keyboard toggle buttons

### Keyboard Input
- Hidden `UIKeyInput` view that becomes first responder on demand
- Map characters to macOS virtual key codes (lookup table)
- Send key_down + key_up pairs per character

### Coordinate Mapping
- Calculate aspect-fit rect of video within view bounds
- Map touch coordinates relative to fit rect → desktop coordinates
- `desktopX = ((touchX - fitRect.minX) / fitRect.width) * desktopWidth`

## Deployment Lessons

### LAN Testing (iOS device → Mac relay)
- Relay binds to `0.0.0.0:8443` (accepts network connections)
- iOS needs `NSAllowsLocalNetworking = true` in Info.plist for plain `ws://`
- User configures relay URL to `ws://<Mac LAN IP>:8443` in app Settings
- Find Mac IP: `ifconfig en0 | grep "inet "`

## Gotchas
- **JWT tokens expire** — regenerate with `cargo run -p relay-server -- --gen-token <subject>`.
- **macOS keyring may not persist between runs** in some environments — hardcode device_id for demos (see `macOSDevelopment.md#keyring-storage`).
- **macOS Screen Recording + Accessibility permissions needed** — first run will prompt.
- **iOS simulator reaches localhost; real device cannot** (use LAN IP).
- **`screencapture` CLI fails until Screen Recording permission is granted** (shows "could not create image from display").
