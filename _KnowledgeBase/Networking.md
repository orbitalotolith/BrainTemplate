---
tags: [reference, networking, rust, quic, apple]
---

# Networking

## WebSocket Streaming Over TCP

### Gotchas

- **Application-level bufferbloat** (as of tokio-tungstenite 0.21+, tungstenite 0.21+): `SplitSink::send()` returns when data is written to the application/TLS write buffer, NOT when it reaches the network. Must call `flush()` after every `send()` to push data through to the OS kernel. Without this, frames accumulate in the application buffer and arrive 30+ seconds late.

- **OS kernel TCP buffer accumulation** (macOS, Linux — general TCP behavior): Even with `flush()`, the OS TCP send buffer (auto-tuned up to several MB on macOS) absorbs data faster than the network can transmit. If production rate exceeds network throughput, frames queue at the kernel level causing increasing lag. `flush()` only prevents application-level buffering; it does NOT wait for TCP ACK or network delivery. Fix: cap production rate to match network capacity (resolution reduction, adaptive frame skipping, or bitrate control).

- **Two-layer bufferbloat fix pattern**: For real-time streaming over TCP WebSocket: (1) `flush()` after every `send()` — fixes application layer. (2) Measure send+flush duration — if it exceeds frame interval, drop frames at the source to prevent kernel buffer accumulation. Both layers must be addressed; fixing only one still causes lag. Reduce bounded channel sizes between pipeline stages to prevent application-level buffering on top of TCP buffering. Note: small messages (mouse events, control messages) don't need flush — they don't fill TCP buffers.

- **Max payload validation**: Always validate incoming payload length against a sane maximum (e.g., 100MB) before allocating buffers. Malformed or malicious length fields can trigger OOM. (general binary protocol pattern)

- **Fixed ports for persistent connections**: Auto-assigned ports (port 0) change on every app restart, making stored connection info stale. Any persistent pairing/connection that stores host:port must use a fixed port. (general networking pattern)

## UDP Broadcast (Wake-on-LAN / magic packets)

### Gotchas

- **`NWConnection` silently drops UDP broadcast packets** (as of iOS 17 / macOS 15): `NWConnection` does not set `SO_BROADCAST` on its underlying UDP socket. Sending to `255.255.255.255` appears to succeed (no error) but packets are never transmitted. Fix: use POSIX BSD sockets directly — `Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)` + `Darwin.setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &enable, socklen_t(MemoryLayout<Int32>.size))` + `Darwin.sendto()`. Required for Wake-on-LAN magic packets. (as of Network.framework / iOS 17 / macOS 15)

## URLSession WebSocket

### Gotchas

- **`timeoutIntervalForRequest` is an idle timeout, not a total timeout** (as of URLSession on iOS 17 / macOS 15): This property controls how long URLSession waits between individual data *transfers* (not the total request duration). For a long-lived WebSocket connection that is idle between sessions (no application data flowing), this kills the connection after N seconds even if WebSocket-level PING frames are sent — PINGs do not count as data transfers for this timeout. Fix: set `config.timeoutIntervalForRequest = 0` (no idle timeout) for persistent WebSocket connections. Use `timeoutIntervalForResource = 0` separately to allow indefinite-duration connections. Note: `timeoutIntervalForRequest = 60` (the default) will silently drop any WebSocket that is idle for more than 60 seconds.

## QUIC — Apple NWConnection (Network.framework)

### Gotchas

- **NWConnection idle timer requires server-initiated PING frames** (as of iOS 15 / macOS 12, Network.framework QUIC): Apple's `NWConnection` only resets its idle timer on *server-initiated* QUIC PING frames. Outgoing client data alone — including heartbeat messages — is insufficient. Without server-side keepalives, NWConnection disconnects after ~60s regardless of traffic volume. Fix (quinn server): set `transport.keep_alive_interval(Some(Duration::from_secs(30)))` in `TransportConfig` before building `ServerConfig`. This triggers periodic QUIC PING from server → resets NWConnection timer. The idle timeout on the server side should be at least 2× the keepalive interval (e.g., 120s idle, 30s keepalive).

- **quinn `accept_bi()` blocks until client sends first** (quinn 0.11): The server's `accept_bi()` call returns only when the remote peer opens a bidirectional stream by sending data. If the client upgrades to QUIC but delays sending (e.g., actor-scheduling latency before first registration message), the server sits at `accept_bi()` indefinitely until the idle timeout fires. Fix: client must send something (even a no-op heartbeat) atomically as part of the upgrade before any async actor boundaries.

- **NWConnection QUIC cert verification with self-signed certs**: Use `sec_protocol_options_set_verify_block` on `NWProtocolQUIC.Options.securityProtocolOptions` to implement custom cert validation. The verify block receives a `sec_trust_t`; call `sec_trust_copy_ref(trust).takeRetainedValue()` to get a `SecTrust`, then `SecTrustCopyCertificateChain` to get the leaf cert. Hash the DER bytes with `SHA256` and compare against a pinned fingerprint. The verify block must call `verifyComplete(Bool)` on `DispatchQueue.global()` — not the queue that received the connection event.

## QUIC — General Architecture

### Patterns

- **Session-aware QUIC upgrades**: When a WebSocket-based session is already active (relay has client registered, session in DashMap), do NOT send MSG_QUIC_INFO to that client. The client's WebSocket close (triggered by QUIC upgrade) causes `unregister_client` → all sessions for that client_id removed → connected peers receive MSG_SESSION_END → they stop sending. Only upgrade entities whose WebSocket closure has no session-side effect (e.g., agent connections that re-register over QUIC immediately after).

- **fly.io QUIC routing**: `[http_service]` handles HTTP/WebSocket (TCP). QUIC/UDP requires a separate `[[services]]` block with `protocol = "udp"`. These coexist in `fly.toml` without conflict. The UDP service does NOT go through the Fly proxy/TLS termination — the app handles its own TLS (rustls + self-signed cert for QUIC).

## STUN (RFC 5389)

### Patterns

- **Minimal STUN binding request**: 20-byte header: type `0x0001` (2 bytes BE), length `0x0000` (2 bytes BE), magic cookie `0x2112A442` (4 bytes BE), transaction ID (12 random bytes). Send over UDP. Parse response for attribute type `0x0020` (XOR-MAPPED-ADDRESS). XOR decode: `(port ^ 0x2112) & 0xFFFF`, IP bytes XORed with magic cookie bytes. No STUN authentication needed for binding requests (auth is only for TURN).
- **NWConnection for UDP STUN on Apple platforms**: Use `NWConnection` with `NWParameters.udp` for STUN. `stateUpdateHandler` → `.ready` fires when the UDP socket is bound (not when server responds — UDP is connectionless). Send binding request in `.ready` handler. Use `receive(minimumIncompleteLength:maximumLength:)` to read response. Set a timeout (e.g., 3s via `DispatchQueue.main.asyncAfter`) since UDP has no delivery guarantee.

## TURN (coturn `use-auth-secret`)

### Patterns

- **Short-lived TURN credentials** (coturn `use-auth-secret` mode): Username = `{expiry_unix}:{user_id}`. Password = `base64(HMAC-SHA1(shared_secret, username))`. coturn validates by recomputing HMAC and checking expiry. Typical validity: 300s. Relay generates and serves via API; clients request fresh credentials at session start. Standard WebRTC TURN credential format — compatible with `RTCIceServer.credential`.
- **Credential generation in Rust**: `hmac = "0.12"` + `sha-1 = "0.10"` + `base64 = "0.22"`. Use `Hmac::<Sha1>::new_from_slice(secret.as_bytes())` → `mac.update(username.as_bytes())` → `base64::STANDARD.encode(mac.finalize().into_bytes())`.

## Cross-Instance WebSocket Routing (Redis pub/sub)

### Patterns

- **Local channels + Redis presence**: Per-process DashMap holds `mpsc::Sender` handles (not serializable). Redis stores which instance owns each connection (`ft:agent:{id}` → `{instance_id}`, TTL 90s). On session message: check local DashMap first; if miss, publish to `ft:relay:{target_instance_id}` channel. Each instance subscribes to its own channel via background task.
- **Binary Redis pub/sub message format**: `kind(1 byte) + id_len(4 bytes LE) + id(id_len bytes) + data(remaining)`. Kinds: `0x01`=agent_message, `0x02`=client_message, `0x03`=session_created, `0x04`=session_ended. Minimal overhead, no JSON overhead for high-frequency video frames.
