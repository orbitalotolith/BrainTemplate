---
tags: [reference, swift, ios, security]
---

# Cross-Platform Crypto

Gotchas for cryptographic operations across platforms and architectures.

## Gotchas

- **Argon2 C reference implementation: ARM vs x86** (architecture issue, not version-specific) — The Argon2 reference C implementation includes an `opt.c` file with x86 SSE/AVX intrinsics (`#include <emmintrin.h>`). This does not compile on ARM targets (iOS devices, Apple Silicon simulators). Fix: replace `opt.c` with the reference (non-optimized) implementation, or exclude `opt.c` from the build target and use `ref.c` instead. Symptom: build errors referencing `emmintrin.h` or `tmmintrin.h`. Note: Argon2 SPM packages are also broken in Xcode 16+ -- embedding C source directly is more reliable (as of Xcode 16.2).

- **CryptoKit AES.GCM.SealedBox combined format** (as of CryptoKit, iOS 15+) — `AES.GCM.SealedBox(combined:)` expects bytes in exactly this order: nonce (12 bytes) + ciphertext (variable) + tag (16 bytes). If the database stores ciphertext+tag in one blob and nonce separately (common pattern), reconstruct as `let combined = nonce + dataBlob`. Swapping the order or omitting the nonce causes `CryptoKit.CryptoKitError.authenticationFailure` with no further diagnostic information. The tag is the last 16 bytes of the combined representation, not the first.
