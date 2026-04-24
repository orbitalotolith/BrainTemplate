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

## Dependency Auditing — cargo audit + npm audit (as of 2026)
- **Prefer fix over ignore.** When an advisory's "Solution" field is a patch/minor bump within the parent's semver range, `cargo update -p <crate>` resolves it via `Cargo.lock` alone — no `Cargo.toml` changes. Verified this pattern for `bytes 1.11.0 → 1.11.1` and `time 0.3.44 → 0.3.47`, both transitives.
- **`cargo audit` can mask advisories behind higher-severity errors.** If a run reports "1 vulnerability found" and you `--ignore` it, the next run may surface additional advisories that weren't in the first log. Always re-run after an ignore to discover what's underneath before declaring the fix complete.
- **`npm audit fix` (without `--force`)** resolves advisories whose fix is available within the current semver range. In a typical Vite 6 / React 18 frontend, this often clears all transitive advisories (vite, rollup, picomatch, minimatch, flatted) with only `package-lock.json` changes — no `package.json` edits. Run tests/build immediately after to confirm no behavioral drift.
- **`--force` only when audit fix can't resolve in-range** — then expect major version bumps that may break the build.
- **Document ignored advisories in-tree** with a dated comment and a revisit trigger: "Remove this ignore next time tauri is upgraded and re-run the audit. Added YYYY-MM-DD." Keeps the reason visible and gives future maintainers an action hook.
