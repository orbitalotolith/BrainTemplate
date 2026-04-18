---
tags: [reference, security]
---
# Security Practices

General security patterns for client-side and server-side applications (as of 2026).

## Password Storage
- **Never store plaintext passwords**
- Use Argon2id for hashing (memory-hard, resistant to GPU/ASIC attacks; recommended by OWASP as of 2025)
- Separate salts for authentication and key derivation

## Encryption at Rest (as of 2026)
- AES-256-GCM for symmetric encryption
- Random nonce per operation (never reuse)
- Store nonce alongside ciphertext (but separately if possible)
- Encrypt/decrypt server-side only — never expose keys to frontend

## Session Management
- Random tokens (64+ chars hex)
- Constant-time comparison to prevent timing attacks
- Auto-lock after inactivity
- Zeroize keys from memory on session end

## Brute-force Protection
- Exponential backoff after N failures
- Persist attempt counters to survive restarts
- Cap delay at reasonable maximum (e.g., 16s)

## Cross-Platform Crypto
- Document exact parameters in a shared reference (algorithm, m/t/p, salt encoding, wire format)
- Test interop: encrypt on platform A, decrypt on platform B
- Watch for encoding differences: Base64 padding, hex vs raw bytes, endianness

## SQLite Security
- Parameterized queries only (never string concatenation)
- Validate inputs at system boundaries
- Use `CHECK` constraints where appropriate

## Trust On First Use (TOFU) Pairing
- Device pairing pattern for E2E encrypted apps: device generates keypair, displays QR code (or short code), peer scans/enters code to exchange public keys
- After initial pairing, subsequent sessions verify static keys during cryptographic handshake — no need to re-pair
- Store pairing keys in platform keychain (iOS Keychain, macOS Keychain/keyring), never in plaintext storage like UserDefaults or SwiftData

## Memory Safety
- Rust: `zeroize` crate for sensitive data
- Never log sensitive data (keys, tokens, passwords)

## Dev Token Management
- Use long-lived tokens (2+ hours) during development — short-lived tokens expire between testing rounds and produce generic "connection failed" errors that waste debugging time
- Always log token expiry timestamps at connection time so expiration is visible
- Provide a quick regeneration command (e.g., `--gen-token` CLI flag) to avoid rebuilds for token refresh
