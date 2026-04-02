# Mesh Plan

## Goal
Build a practical offline mesh network for Proxi Premium that can carry messages across 500 meters or more by chaining nearby devices as relays. The design must work with no internet, preserve encryption, survive app restarts, and degrade cleanly in weak radio conditions.

## Reality Check
500 meters is not a realistic single-hop Bluetooth range. The only viable way to reach that span is multi-hop routing through multiple phones. The plan below is written around relay chains, not a single device-to-device radio link.

## Current Mesh Stack
The repo already contains a mesh-oriented implementation with BLE discovery, BLE advertising, Wi-Fi Direct transport, local SQLite persistence, encryption, and Firebase sync.

- [mobile_app/lib/services/mesh_service.dart](mobile_app/lib/services/mesh_service.dart)
- [mobile_app/lib/ble_service.dart](mobile_app/lib/ble_service.dart)
- [mobile_app/lib/services/wifi_direct_service.dart](mobile_app/lib/services/wifi_direct_service.dart)
- [mobile_app/lib/services/mesh_db_service.dart](mobile_app/lib/services/mesh_db_service.dart)
- [mobile_app/lib/services/mesh_encryption_service.dart](mobile_app/lib/services/mesh_encryption_service.dart)
- [mobile_app/lib/services/mesh_sync_service.dart](mobile_app/lib/services/mesh_sync_service.dart)
- [mobile_app/lib/screens/mesh_chat_screen.dart](mobile_app/lib/screens/mesh_chat_screen.dart)

## Scope
- BLE advertisement and discovery
- Wi-Fi Direct peer connection setup
- Message relay and forwarding
- Route selection and hop control
- Offline persistence and replay
- Encryption and deduplication
- Mesh UI status and debugging tools
- Outdoor range testing and tuning

## Phase 1: Restore and Stabilize Mesh Core
- Re-enable the mesh chat flow in the UI and connect it to the existing services.
- Verify BLE scan and advertising lifecycle works without disrupting normal nearby discovery.
- Verify Wi-Fi Direct initialization, peer discovery, group formation, and socket connection.
- Confirm message send, receive, and local storage work end to end on two devices first.

## Phase 2: Extend Range Through Multi-Hop Relay
- Make relay forwarding the primary way to extend network span beyond direct radio range.
- Use hop-limited forwarding with a configurable ceiling instead of a fixed low limit.
- Start conservatively, then tune upward after real field tests.
- Prefer relay peers with stronger links, lower congestion, and better connection stability.
- Drop loops and duplicate packets aggressively to avoid broadcast storms.

## Phase 3: Improve Routing Quality
- Add packet metadata for path, hop count, and remaining TTL.
- Prefer stable peers over weak or flaky peers.
- Keep a small recent-message cache so relayed packets are not processed twice.
- Add backoff and retry for temporarily unavailable peers.
- Store and forward pending relay packets from local SQLite when a link is unavailable.

## Phase 4: Harden Reliability
- Persist pending, relayed, delivered, and synced states locally.
- Re-deliver unsent mesh messages when peers reconnect.
- Resume mesh discovery automatically after disconnects.
- Keep mesh state alive across app restarts where possible.
- Make the system resilient to permission loss, Bluetooth off, and Wi-Fi Direct failures.

## Phase 5: Security and Integrity
- Keep all mesh payloads encrypted before they leave the device.
- Ensure only encrypted payloads are transmitted and synced.
- Keep message IDs globally unique.
- Validate packet structure before forwarding.
- Reject malformed packets, oversized payloads, and replay attempts.

## Phase 6: UI and Diagnostics
- Show mesh states clearly: inactive, scanning, discovered, connected, relaying, syncing.
- Show peer count, socket count, hop count, and delivery status.
- Add warnings when the network is near range limits.
- Add a debug panel for signal quality, connected peers, and relay path tracing.
- Make it obvious when the app is trying to maximize range through relays.

## Phase 7: Field Testing
- Test with 2 devices at short range.
- Test with 3 to 5 devices in a chain outdoors.
- Test open-field coverage and obstacles separately.
- Measure stable relay span at 100m, 250m, 500m, and beyond.
- Test battery drain, reconnect time, message latency, and packet loss.
- Record results and tune hop limit, scan intervals, and relay timeouts.

## Acceptance Criteria
- Two devices can exchange messages offline with no internet.
- Messages can traverse multiple hops and still arrive correctly.
- The mesh can span 500 meters or more in a realistic outdoor chain of devices.
- Duplicate packets are not delivered twice.
- Messages survive app restart.
- Encryption remains enabled for all mesh payloads.
- The UI shows mesh status clearly and does not break normal chat.

## Implementation Todo Plan
1. Re-enable mesh chat entry points in the UI.
2. Verify BLE advertising and scanning are actually active during mesh mode.
3. Verify Wi-Fi Direct peer discovery and socket transport still work end to end.
4. Confirm local SQLite persistence of outgoing, incoming, and relayed messages.
5. Add relay metadata: hop count, TTL, path, and duplicate protection.
6. Add routing preference rules for stable peers and link quality.
7. Add reconnect and retry behavior for dropped peers.
8. Add debug UI for peer count, hop count, and connection state.
9. Field test in a 2-device setup, then a 3-to-5-device chain.
10. Tune limits and retry intervals based on real results.

## Implementation Prompt
You are working on Proxi Premium’s offline mesh networking.

Current stack:
- Flutter app
- BLE discovery and advertising
- Wi-Fi Direct transport over native Android
- Local SQLite storage
- Firebase sync when internet returns
- Existing mesh code already exists, but it needs to be stabilized, re-enabled in the UI, and extended for longer multi-hop coverage

Task:
Implement a robust offline mesh system that can reach 500 meters or more through multi-hop relays.

Requirements:
- Do not claim 500m as a single-hop Bluetooth range
- Use multi-hop relay to extend network span
- Keep all payloads encrypted
- Deduplicate packets
- Persist unsent and relayed messages locally
- Recover automatically after disconnects
- Expose clear UI states for scanning, connecting, relaying, and syncing
- Optimize for maximum practical outdoor range
- Add diagnostics for hop count, peer stability, and delivery status
- Validate on real Android devices

Deliverables:
- A working mesh chat flow
- Relay-aware routing
- Stable offline messaging
- Range testing notes
- A concise summary of limits and expected real-world range

## Working Notes
- Keep the plan aligned with the existing mesh code instead of rewriting the stack from scratch.
- Treat 500 meters as a chain-of-devices target.
- Measure real-world results before increasing hop limits.
- Keep the user-facing wording honest about range and environmental dependence.
