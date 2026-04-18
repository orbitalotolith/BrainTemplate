---
tags: [reference, security, encryption, noise-protocol]
---

# Noise Protocol Implementation Guide

Canonical reference for the Noise protocol handshake (XX pattern) state machine and primitive functions. For platform-specific implementation details, see also:
- `cryptokit-noise-interop.md` — Apple CryptoKit interop gotchas
- `RustSnowLibrary.md` — Rust `snow` library API and usage

## Critical: Empty Payload MixHash

**Every Noise message ends with `EncryptAndHash(payload)` — even when the payload is empty and there's no cipher key yet.** This is the most common interop bug.

For msg1 (`-> e`), after MixHash(ephemeral_pubkey), you MUST also call MixHash("") for the empty payload. Without this, `h` is one SHA256 iteration behind and ALL subsequent AEAD operations fail with authentication errors.

```
// WRONG — missing empty payload hash
writeMessage1():
  MixHash(eph_pub)
  return eph_pub

// CORRECT
writeMessage1():
  MixHash(eph_pub)
  MixHash("")        ← this is EncryptAndHash(empty_payload) with no cipher key
  return eph_pub
```

This applies to EVERY message in the pattern, not just msg1. After processing all tokens (e, ee, s, es, se), there's always a final EncryptAndHash(payload) step.

## Noise XX Handshake State Machine

Pattern: `Noise_XX_25519_ChaChaPoly_SHA256`

### Initialization
```
h = protocol_name  (pad to HASHLEN=32 if shorter, SHA256 if longer)
ck = h
MixHash(prologue)   ← even empty prologue: h = SHA256(h)
```

### msg1: -> e (initiator sends)
```
Generate ephemeral keypair
MixHash(e.public_key)
EncryptAndHash("")      ← empty payload, no key = just MixHash("")
Output: e.public_key (32 bytes)
```

### msg2: <- e, ee, s, es (responder sends)
```
Generate ephemeral keypair
MixHash(e.public_key)                          ← write resp ephemeral (32 bytes)
MixKey(DH(resp_eph, init_eph_pub))             ← ee: sets cipher_key, resets nonce=0
EncryptAndHash(resp_static_pub)                ← encrypt with cipher_key (48 bytes: 32+16 tag)
MixKey(DH(resp_static, init_eph_pub))          ← es: new cipher_key, nonce=0
EncryptAndHash("")                              ← empty payload (16 bytes: just tag)
Output: 32 + 48 + 16 = 96 bytes
```

### msg3: -> s, se (initiator sends)
```
EncryptAndHash(init_static_pub)                ← encrypt with current cipher_key (48 bytes)
MixKey(DH(init_static, resp_eph_pub))          ← se: new cipher_key, nonce=0
EncryptAndHash("")                              ← empty payload (16 bytes)
Output: 48 + 16 = 64 bytes
```

### Transport
After msg3: `split()` derives send/recv keys from HKDF(ck, "").

## Primitive Functions

### MixHash(data)
```
h = SHA256(h || data)
```

### MixKey(shared_secret)
```
(ck, cipher_key) = HKDF(ck, shared_secret, 2)
nonce = 0
```

### HKDF(salt, ikm) → (output1, output2)
```
temp_key = HMAC-SHA256(salt, ikm)          ← salt=chaining_key, ikm=shared_secret
output1  = HMAC-SHA256(temp_key, 0x01)
output2  = HMAC-SHA256(temp_key, output1 || 0x02)
```

This is standard RFC 5869 HKDF with empty `info`. CryptoKit's `HKDF<SHA256>.deriveKey(inputKeyMaterial:salt:info:outputByteCount:)` with `info: Data()` and `outputByteCount: 64` is equivalent.

### EncryptAndHash(plaintext)
```
If no cipher key: ciphertext = plaintext (identity)
Else: ciphertext = ChaCha20-Poly1305(key, nonce++, ad=h, plaintext)
MixHash(ciphertext)
Return ciphertext
```

### Nonce encoding (ChaCha20-Poly1305)
```
12 bytes: [0,0,0,0] + counter_u64_little_endian
```

## Gotchas

- **Empty payload MixHash** (as of snow 0.9.6): The Noise spec requires EncryptAndHash(payload) at the end of every message. Libraries like `snow` handle this automatically in `write_message`/`read_message`. Hand-rolled implementations must do it explicitly. See `cryptokit-noise-interop.md` for CryptoKit-specific implications.

- **MixHash(prologue) even when empty**: After init, `MixHash(prologue)` must be called even with empty prologue. This changes `h` (h = SHA256(h)) but NOT `ck`.

- **AEAD ciphertext format**: `ciphertext_bytes || poly1305_tag (16 bytes)`. Split at `len - 16` for decrypt.

- **CryptoKit interop**: See `cryptokit-noise-interop.md` for HKDF parameter mapping, X25519 compatibility, nonce format, and the critical HKDF divergence that prevents CryptoKit from being used for Noise transport keys.

## Testing Cross-Implementation Compatibility

Use `snow`'s `fixed_ephemeral_key_for_testing_only` to create deterministic handshakes:
```rust
let initiator = snow::Builder::new(pattern.parse()?)
    .local_private_key(&static_key)
    .fixed_ephemeral_key_for_testing_only(&eph_key)
    .build_initiator()?;
```

Then manually replicate the same handshake with your custom implementation using the same keys and compare intermediate `h` values at each step.
