---
tags: [reference, swift, rust]
---

# Swift / C / Rust Interop

Cross-language gotchas when bridging Swift with C or Rust code.

## Gotchas

- **Base64 padding mismatch between Rust and Swift** (not version-specific) — Rust's `base64::engine::general_purpose::STANDARD_NO_PAD` encodes without `=` padding. Swift's `Data(base64Encoded:)` expects padded Base64 by default. If a salt or key is stored without padding (e.g., from Rust), Swift decoding silently produces different bytes or nil. Fix: re-add padding before decoding in Swift: `saltStr + String(repeating: "=", count: (4 - saltStr.count % 4) % 4)`. Getting this wrong produces a different hash and silent auth failure.

- **Swift/C enum comparison requires .rawValue** (not version-specific) — C enums imported into Swift via bridging headers become Swift types, not raw integers. Comparing directly (e.g., `result == ARGON2_OK`) may compile but behave unexpectedly depending on context. Always compare with `.rawValue`: `result == ARGON2_OK.rawValue`. This applies to any C enum used in Swift, not just Argon2.
