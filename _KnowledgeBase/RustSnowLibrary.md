---
tags: [reference, rust, security, encryption, noise-protocol]
---

# Rust `snow` Library — Noise Protocol Implementation

`snow` is the standard Rust library for the Noise protocol framework (as of snow 0.9.x). For the canonical protocol state machine, see `noise-protocol-implementation.md`. For CryptoKit interop, see `cryptokit-noise-interop.md`.

## Basic Usage

```rust
use snow::Builder;

let pattern = "Noise_XX_25519_ChaChaPoly_SHA256";

// Generate keypair (static identity key)
let keypair = Builder::new(pattern.parse()?).generate_keypair()?;
// keypair.private: Vec<u8> (32 bytes, unclamped X25519 scalar)
// keypair.public: Vec<u8> (32 bytes, Montgomery u-coordinate)

// Build initiator
let mut initiator = Builder::new(pattern.parse()?)
    .local_private_key(&keypair.private)
    .build_initiator()?;

// Build responder
let mut responder = Builder::new(pattern.parse()?)
    .local_private_key(&other_keypair.private)
    .build_responder()?;
```

## Handshake Message Exchange

```rust
let mut buf = vec![0u8; 65535];
let mut payload_buf = vec![0u8; 65535];

// msg1: initiator → responder
let len = initiator.write_message(&[], &mut buf)?;   // payload=[] (empty)
responder.read_message(&buf[..len], &mut payload_buf)?;

// msg2: responder → initiator
let len = responder.write_message(&[], &mut buf)?;    // 96 bytes for XX
initiator.read_message(&buf[..len], &mut payload_buf)?;

// msg3: initiator → responder
let len = initiator.write_message(&[], &mut buf)?;    // 64 bytes for XX
responder.read_message(&buf[..len], &mut payload_buf)?;

// Both sides now in transport mode
let mut initiator_transport = initiator.into_transport_mode()?;
let mut responder_transport = responder.into_transport_mode()?;
```

## Transport Mode (Post-Handshake)

```rust
// Encrypt
let len = transport.write_message(b"hello", &mut buf)?;
// buf[..len] = ciphertext || tag

// Decrypt
let len = transport.read_message(&buf[..len], &mut payload_buf)?;
// payload_buf[..len] = plaintext
```

## Key Concepts

- **`write_message(&payload, &mut output)`**: Processes all handshake tokens for the current message, then EncryptAndHash(payload). Returns total output bytes. Payload can be empty `&[]`.
- **`read_message(&input, &mut payload)`**: Inverse of write_message. Processes tokens and DecryptAndHash. Returns payload length.
- **`into_transport_mode()`**: Called after all handshake messages. Returns `TransportState` for encrypt/decrypt.
- **`is_handshake_finished()`**: True after all 3 messages (for XX pattern).
- **`get_remote_static()`**: Returns peer's static public key after handshake. Use for identity verification.

## C FFI Pattern (for iOS/macOS Swift interop)

Snow doesn't have C bindings. Wrap it in opaque context structs:

```rust
pub struct NoiseHandshakeCtx {
    handshake: snow::HandshakeState,
    session: NoiseSession,  // holds transport state after finalize
}

pub struct NoiseTransportCtx {
    session: NoiseSession,  // encrypt/decrypt methods
}

#[no_mangle]
pub extern "C" fn noise_responder_new() -> *mut NoiseHandshakeCtx { ... }

#[no_mangle]
pub unsafe extern "C" fn noise_responder_process(
    ctx: *mut NoiseHandshakeCtx,
    msg_ptr: *const u8, msg_len: usize
) -> FFIBuffer { ... }

#[no_mangle]
pub unsafe extern "C" fn noise_responder_finalize(
    ctx: *mut NoiseHandshakeCtx
) -> *mut NoiseTransportCtx { ... }
```

Swift side: `OpaquePointer` for the context, `Data.withUnsafeBytes` for passing buffers.

## Internal Architecture (as of snow 0.9.6)

- **Resolvers**: Pluggable crypto backends. Default uses `curve25519-dalek` (DH), `chacha20poly1305` (AEAD), `sha2`/`blake2` (hash).
- **SymmetricState**: Manages `h` (handshake hash), `ck` (chaining key), cipher state. Internal arrays are `MAXHASHLEN=64` bytes but only first `hash_len()=32` bytes used for SHA256.
- **CipherState**: Wraps AEAD cipher + nonce counter. `encrypt_ad`/`decrypt_ad` auto-increment nonce.
- **HandshakeState**: Drives the token-by-token state machine. `write_message` processes tokens then EncryptAndHash(payload). `read_message` is the inverse.
- **DH**: `Dh25519` stores raw 32-byte privkey. `mul_base_clamped` for pubkey derivation, `mul_clamped` for DH. Clamping applied internally.
- **HKDF**: Custom implementation in `types.rs::Hash::hkdf`. Uses manual HMAC (ipad/opad XOR) then Noise-spec HKDF expand. NOT the `hkdf` crate — but produces identical output.
- **Nonce**: ChaCha20-Poly1305 uses `[0,0,0,0] + counter_u64_LE` (12 bytes). AES-GCM uses `[0,0,0,0] + counter_u64_BE`.

## Testing

```rust
// Fixed ephemeral key for deterministic tests
let initiator = Builder::new(pattern.parse()?)
    .local_private_key(&static_key)
    .fixed_ephemeral_key_for_testing_only(&eph_key)
    .build_initiator()?;
```

Use `generate_keypair()` to create test keys in the correct format:
```rust
let kp = Builder::new(pattern.parse()?).generate_keypair()?;
// kp.private and kp.public are in snow-compatible format
```

## Gotchas

- **`write_message` buffer must be large enough** (as of snow 0.9.6): At least `payload.len() + handshake_overhead`. Use 65535 for safety.
- **`read_message` output buffer** (as of snow 0.9.6): Must be large enough for decrypted payload. `handshake_payload.len() - TAGLEN` for encrypted messages.
- **Key format** (as of snow 0.9.6): `generate_keypair().private` returns raw unclamped bytes. `local_private_key()` accepts these directly. Don't pre-clamp.
- **Thread safety** (as of snow 0.9.6): `HandshakeState` and `TransportState` are `!Send` — wrap in `Mutex` for async contexts.
- **Cargo features** (as of snow 0.9.6): Default features include `default-resolver` (curve25519-dalek + chacha20poly1305). For `ring` backend: `snow = { version = "0.9", features = ["ring-resolver"], default-features = false }`.
- **Protocol-level gotchas**: See `noise-protocol-implementation.md` Gotchas section for empty payload MixHash, prologue handling, and AEAD format.
