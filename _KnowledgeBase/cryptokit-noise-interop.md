---
tags: [reference, ios, swift, security, encryption]
---

# CryptoKit + Noise Protocol Interop

Gotchas when implementing Noise protocol with Apple CryptoKit primitives, especially interop with Rust `snow` library. For the canonical protocol state machine, see `noise-protocol-implementation.md`.

## Gotchas

- **Empty payload MixHash after every message** (as of snow 0.9.x, CryptoKit iOS 17+; discovered 2026-03-27): The Noise spec requires `EncryptAndHash(payload)` at the end of every `write_message`/`read_message`, even for empty payloads with no cipher key. With no key, this reduces to `MixHash(Data())` which is `h = SHA256(h)`. Missing this causes `h` to diverge by one SHA256 iteration, making ALL subsequent AEAD decryptions fail with CryptoKitError.authenticationFailure. `snow` handles this automatically; hand-rolled CryptoKit code must do it explicitly after each message's tokens are processed.

- **MixHash(prologue) with empty prologue** (as of snow 0.9.x, CryptoKit iOS 17+; discovered 2026-03-27): After initialization (`h = protocol_name`, `ck = h`), MixHash(prologue) must be called even with empty prologue. This hashes `h` once more (`h = SHA256(h)`) but does NOT change `ck`. `snow` does this in `HandshakeState::initialize`. CryptoKit code must add `handshakeHash = Data(SHA256.hash(data: handshakeHash))` after init.

- **CryptoKit HKDF diverges from snow for transport keys** (as of CryptoKit iOS 17+; discovered 2026-03-28): Despite the handshake completing successfully (intermediate keys correct, encrypted payloads verified), CryptoKit's Noise XX implementation produces different transport keys from `split()` than snow. Manual Rust reimplementation of the CryptoKit algorithm with raw HMAC/SHA256/ChaCha20 matches snow perfectly — proving the algorithm is correct but CryptoKit's primitives have a subtle behavioral difference. Fix: use snow via Rust FFI on both iOS and macOS. Do NOT use CryptoKit for Noise protocol crypto.

- **CryptoKit X25519 matches snow**: `Curve25519.KeyAgreement.PrivateKey.sharedSecretFromKeyAgreement` produces the same shared secret as `MontgomeryPoint::mul_clamped` in curve25519-dalek. `SharedSecret.withUnsafeBytes { Data($0) }` gives raw 32-byte X25519 output.

- **CryptoKit nonce format**: `ChaChaPoly.Nonce(data:)` accepts 12 bytes. Noise nonce is `[0,0,0,0] + counter_u64_LE`. Create with: `var bytes = Data(repeating: 0, count: 4); withUnsafeBytes(of: counter.littleEndian) { bytes.append(contentsOf: $0) }`.

- **AEAD associated data**: `ChaChaPoly.seal(..., authenticating: handshakeHash)` and `ChaChaPoly.open(..., authenticating: handshakeHash)` use the current `h` as AD. This MUST match between encrypt and decrypt sides — any `h` divergence causes auth failure.

- **CryptoKitError error 3 = authenticationFailure**: When `ChaChaPoly.open` fails, the error description shows "CryptoKit.CryptoKitError error 3". This means the AEAD tag didn't verify — the key, nonce, AD, or ciphertext doesn't match what was used for encryption. Almost always caused by `h` (handshake hash) divergence.

## Debugging Cross-Implementation Failures

1. Write a pure-Rust test using `snow`'s `fixed_ephemeral_key_for_testing_only` with known keys
2. Manually replicate the handshake state machine using raw crypto crates (sha2, hmac, chacha20poly1305, x25519-dalek)
3. Compare `h` at each step — the first divergence is the bug
4. If manual Rust matches snow: bug is in CryptoKit parameter mapping
5. If manual Rust diverges from snow: bug is in the state machine logic (likely missing a MixHash/EncryptAndHash step)
