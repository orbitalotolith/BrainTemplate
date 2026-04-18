---
tags: [reference, ble]
---
# BLE Development Notes

## Core Concepts
- **Central:** Scans for and connects to peripherals (iPhone with CoreBluetooth)
- **Peripheral:** Advertises services, accepts connections (Desktop with bluer/CoreBluetooth)
- **GATT:** Service → Characteristic hierarchy. Read/write/notify.

## Rust Libraries
- **btleplug:** Central-only. Cannot advertise as peripheral. (as of btleplug 0.11; verify current version — last reviewed 2026-04-04)
- **bluer:** Linux-only (BlueZ D-Bus). Supports both central and peripheral roles. Use `bluetoothd` feature (not `gatt`). (as of bluer 0.15; verify current version — last reviewed 2026-04-04)

## iOS (CoreBluetooth)
- `CBCentralManager` for scanning/connecting
- `CBPeripheralManager` for advertising (if needed)
- BLE not available in iOS Simulator — need physical device (as of iOS 17; Apple has not added simulator BLE support)

## Chunking Protocol Pattern
For data larger than MTU:
1. Split into chunks with header: index + total + CRC32
2. Each chunk independently verifiable via CRC32
3. Reassembler handles out-of-order delivery
4. ACK per chunk for reliability

## Security Pattern (ECDH + HKDF)
1. Both sides generate ephemeral P-256 keypairs
2. Exchange public keys (compressed SEC1, 33 bytes)
3. ECDH shared secret → HKDF with application-specific info string → session key
4. HMAC verification confirms both derived same key
5. AES-256-GCM transport encryption with session key

## Gotchas
- MTU negotiation varies by platform — always check `maximumWriteValueLength` before writing
- bluer write API uses event streams, not callbacks (as of bluer 0.15; verify if API changes in major version)
- Background BLE on iOS requires `UIBackgroundModes: bluetooth-central` and careful state restoration (as of iOS 17)
