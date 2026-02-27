# PROXI — Feature Explanation & Known Issues

---

## WHY YOUR FRIEND 15 KM AWAY APPEARED IN "BLUETOOTH MO DE"

This is a BUG in the current code.

In `lib/app_state.dart`, the `scanNearby()` function should use real BLE
scan results to match users. But currently it does this:

```
if (discoveryMode == DiscoveryMode.ble) {
  await ble.init();          ← only requests permissions
  await Future.delayed(2s)   ← fake "scan" delay
  final allUsers = await firebase.getNearbyUsers();  ← fetches ALL discoverable users from Firestore!
}
```

It IGNORES BLE scan results completely and just fetches every user with
`discoverable: true` from Firestore — no distance filter whatsoever.
That is why someone 15 km away appeared. It is NOT real Bluetooth proximity.

---

## HOW IT SHOULD WORK (correct behavior)

### Bluetooth BLE Mode — Real Range: 10–15 meters (indoors), up to 30m (open air)
- Phone broadcasts a BLE advertisement with a unique UUID tied to the user account.
- Nearby phones scan for that UUID.
- Only users whose phone BLE signal is physically detected (RSSI threshold) appear in the list.
- Walls, metal objects, and crowds reduce range. Expected real-world range: 5–15m.
- BLE does NOT work across streets, buildings, or km distances.
- It is designed for: crowded events, offices, conferences, cafés.

### GPS Mode — Real Range: configurable (currently hardcoded 10 km in code)
- App reads device GPS coordinates (lat/lng).
- Uploads them to Firestore.
- Queries Firestore for other users within X km using Haversine formula.
- Currently set to 10 km radius in `app_state.dart` → `getNearbyByGps(..., 10)`.
- Accuracy: 5–10m outdoors, 10–50m in urban areas, unreliable indoors.
- This correctly filters by distance — only GPS mode works as intended right now.

---

## ALL FEATURES (current state)

### 1. Dual-Mode Toggle (Formal ↔ Casual)
- One-tap switch between PRO (professional) and SOCIAL (casual) mode.
- Feed, posts, reels, jobs are all mode-specific.
- Status: ✅ Working

### 2. Authentication (Email/Password)
- Sign up, sign in, sign out, password reset via Firebase Auth.
- Status: ✅ Working

### 3. Feed
- Real-time stream of posts filtered by mode (formal/casual).
- Like, comment, delete own posts.
- Status: ✅ Working

### 4. Stories (24-hour expiry)
- Create stories with image/video.
- Stories auto-expire after 24 hours (via Firestore `expires_at` field).
- Tap to reply → opens DM.
- Delete own story: ❌ NOT IMPLEMENTED YET (needs to be added)
- Status: ⚠️ Partial (missing delete)

### 5. Reels (Casual mode)
- Short-form vertical videos.
- View count, like, scroll feed.
- Status: ✅ Working

### 6. Jobs (Formal mode)
- Post and browse job listings with skills, salary, location.
- Apply to jobs.
- Status: ✅ Working

### 7. Real-Time Chat (DMs)
- Direct messages with text and image sharing.
- Delete/clear chat: ❌ NOT IMPLEMENTED YET (needs to be added)
- Status: ⚠️ Partial (missing delete/clear)

### 8. Group Chat
- Create group conversations with 2+ connections.
- Delete/clear group chat: ❌ NOT IMPLEMENTED YET (needs to be added)
- Status: ⚠️ Partial (missing delete/clear)

### 9. Notifications
- In-app notifications for likes, comments, connection requests, messages.
- Push notifications: structure in place, FCM token stored, full delivery depends on Cloud Functions (not yet set up).
- Status: ⚠️ In-app OK, push needs Cloud Functions

### 10. Connection System
- Send/accept/decline connection requests.
- BUG: When connected, the follow/unfollow is one-directional.
  Should be: connected = mutual follow (A follows B AND B follows A).
  Currently: only the requester follows the target on accept.
- Status: ⚠️ Bug in followers/following (fix needed)

### 11. Nearby Discovery — BLE Mode
- BUG: Does NOT use real BLE proximity. Fetches all discoverable users from Firestore.
- Appears to work but shows users regardless of physical distance.
- Fix needed: match Firestore users to actual BLE scan device UUIDs.
- Status: ❌ Broken (shows all users, not nearby ones)

### 12. Nearby Discovery — GPS Mode
- Working correctly. Filters users within 10 km using Haversine distance.
- Status: ✅ Working (radius = 10 km)

### 13. Profile
- Edit name, bio, avatar (formal + casual), skills, experience, education.
- Status: ✅ Working

### 14. Privacy Settings
- Public / Connections Only visibility toggle.
- Discoverable toggle (controls if you appear in nearby scans).
- Status: ✅ Working

---

## THINGS TO FIX / ADD (Priority Order)

1. FIX — BLE mode: use actual BLE scan UUIDs to match users (not Firestore dump)
2. FIX — Followers/Following: accepting a connection must set both users as mutual followers
3. ADD — Delete story (button on own story in story viewer)
4. ADD — Delete/clear DM chat
5. ADD — Delete/clear group chat
6. TEST — All features end-to-end with 2 accounts
7. UPDATE — README with accurate feature status
8. PUSH — To GitHub

---

## GPS vs BLE QUICK REFERENCE

| | BLE | GPS |
|---|---|---|
| Real range | 10–15 m | Up to 10 km (configurable) |
| Works indoors | ✅ Yes | ❌ Poor |
| Works outdoors | ✅ Yes | ✅ Best |
| Battery usage | Low | Medium |
| Current status in app | ❌ BUG (no real proximity filter) | ✅ Working |
| Best use case | Events, offices, cafés | Outdoor parks, cities |

