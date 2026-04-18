---
tags: [reference, rust, deployment]
---

# fly.io Deployment (Rust)

## Gotchas

- **glibc mismatch** (as of rust:latest / debian:bookworm-slim, 2026): Use `rust:latest` for BOTH builder and runtime Dockerfile stages. Mixing `rust:latest` builder with `debian:bookworm-slim` runtime causes "GLIBC_2.38 not found" at startup.
- **TLS and WebSocket routing**: Use `[http_service]` in `fly.toml` for automatic `.fly.dev` TLS and native WebSocket upgrade support. Raw `[[services]]` is TCP passthrough only — no auto-certs, and WebSocket connections drop after ~5 seconds.
- **IP allocation**: Allocate IPs after creating the app: `fly ips allocate-v4 --shared` + `fly ips allocate-v6`.
- **Region capacity**: If a region is full ("insufficient resources"), try `iad` or `sjc` instead of `ord`.
- **Cargo workspace Dockerfile**: Dockerfile must be at workspace root if the crate depends on sibling crates in a Cargo workspace.
- **Always-on services**: `auto_stop_machines = "off"` to prevent fly from stopping the machine when idle — required for always-on WebSocket agents.
- **HA on fly.io**: `min_machines_running = 2` under `[http_service]` ensures at least 2 machines always run. Required for cross-instance routing via Redis — if only one machine, Redis pub/sub is never needed but presence keys still work correctly.
- **Multi-instance DashMap state is NOT shared** (as of 2026): In-memory state (DashMap for agents, clients, sessions) is per-instance. Only explicit DB-backed or Redis-backed data is shared. If instance A holds an agent's WebSocket and instance B receives a pairing confirm, `forward_to_agent()` fails silently. Store cross-instance coordination data in PostgreSQL (pairings, pending state) or Redis (session routing, presence). Scale to 1 machine if Redis is not configured.
- **Dead host: `[PU03] unreachable worker host`** (as of 2026): fly.io proxy returns this when the underlying host dies. Machine shows `started` with 💀 in `fly status`. Fix: `fly machine destroy <id> --force`, then redeploy. The fly.io `fly secrets deploy` command may crash with SIGSEGV on affected machines — use `fly deploy` instead.
- **Removing SQLite volumes**: `[[mounts]]` blocks are persistent (survive deploys). Remove the entry from `fly.toml` AND run `fly volumes destroy <vol_id>` to free storage. Stale volumes still charge if orphaned.
