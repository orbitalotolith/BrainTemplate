---
tags: [reference, security, encryption, architecture]
---

# E2E Encryption Patterns for Client-Server Apps

Patterns for implementing end-to-end encryption in apps that communicate through a relay/server. Architecture based on Noise Protocol Framework (as of 2026; protocol is stable/finalized).

## Architecture: Noise XX over WebSocket/TLS

The relay is **zero-knowledge** — it routes encrypted bytes without inspecting them.

```
iOS Client ←→ Cloud Relay ←→ macOS Agent
   (initiator)   (router)    (responder)
```

- **Transport**: WebSocket over TLS 1.3 (relay ↔ endpoints)
- **E2E**: Noise XX (Curve25519 + ChaCha20-Poly1305 + SHA256) over the transport
- TLS protects relay ↔ endpoint. Noise protects client ↔ agent E2E.

## Handshake Flow Within Session Establishment

1. Client sends MSG_SESSION_REQUEST to relay
2. Relay creates session, sends MSG_SESSION_READY to both sides
3. Agent sends MSG_CAPABILITIES (includes `noiseEnabled: bool`)
4. If noise enabled:
   - Client sends MSG_NOISE_HANDSHAKE with msg1 (32 bytes)
   - Agent responds with MSG_NOISE_HANDSHAKE with msg2 (96 bytes)
   - Client sends MSG_NOISE_HANDSHAKE with msg3 (64 bytes)
5. Transport keys established — all subsequent frames encrypted

## Race Condition: Handshake vs Streaming

**Problem**: If the remote side's data pipeline is already running (reconnect scenario), data frames arrive at the client BEFORE the handshake messages. The relay starts routing to the new session immediately upon creation — before the remote side even knows about it.

**Fix**: Client must loop and skip data frames while waiting for capabilities and handshake messages:
```swift
// Skip data frames, wait for MSG_NOISE_HANDSHAKE
while let candidate = await iterator.next() {
    if msgType == .noiseHandshake { break }
    if msgType == .sessionEnd { fail; return }
    // Skip data frames, late capabilities, display info
}
```

Add a frame-skip counter (cap based on expected frame rate) to prevent infinite loops if the remote side never responds.

## Key Storage

- **Ephemeral keys**: In-memory only (generated per handshake, never stored)
- **Static identity keys**: iOS = Keychain (`KeychainService`), macOS/Rust = file-based state dir
- **Shared secrets**: Derived in-memory, zeroized after use
- **No Secure Enclave difference**: Noise session keys are ephemeral — hardware key storage doesn't apply to them. CryptoKit vs software crypto is equivalent security for Noise.

## Implementation Choice: Single Library vs Cross-Language

**Strongly prefer using the SAME crypto library on both sides.** Cross-implementation bugs are extremely hard to debug — the Noise state machine has many implicit steps (empty payload MixHash, MixHash(prologue)) that hand-rolled implementations miss.

Options (as of snow 0.9.x, CryptoKit iOS 17+):
- **Rust `snow` on both sides** via FFI (most reliable for Rust backends)
- **libsodium** on both sides (good C FFI from any language)
- **CryptoKit** on Apple side + `snow` on Rust side (requires very careful spec compliance — see `_KnowledgeBase/noise-protocol-implementation.md`)

## Protocol Message Format

Binary header (8 bytes) + msgpack payload:
```
[msg_type: u8] [flags: u8] [sequence: u16] [payload_length: u32]
```

Noise handshake messages use `msg_type = 0x20`. Encrypted frames use `FLAG_ENCRYPTED = 0x04` — the receiver checks this flag and decrypts via the established Noise transport.
