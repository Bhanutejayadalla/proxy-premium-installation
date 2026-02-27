# Proxi — Social Features Guide

This guide explains how **Connections**, **Followers**, and **Following** work in Proxi, with step-by-step instructions for each action.

---

## Key Concepts

| Term | Meaning |
|------|---------|
| **Connection** | A mutual relationship (like LinkedIn). Both users must agree. Accepting auto-follows both users. |
| **Follower** | Someone who follows you. They see your content; you don't necessarily follow them back. |
| **Following** | Someone you follow. You see their content in your feed. |
| **Mode-Specific** | Each mode (Pro / Social) has its own followers, following, and connections lists. |

### Connection vs Follow — What's the Difference?

| Feature | Connection | Follow |
|---------|-----------|--------|
| Requires approval? | **Yes** — the other person must accept | **No** — automatic when connection accepted |
| Mutual? | **Yes** — both users are connected | **No** — one-directional |
| How to initiate | Send a Connection Request | Happens automatically on connection accept |
| Can you follow without connecting? | No — follow is created via connections | No — follow is tied to connections |

> **In Proxi, following is always tied to connections.** When a connection is accepted, both users automatically follow each other in that mode. When a connection is removed, both are unfollowed.

---

## How to Send a Connection Request

### From the Nearby Screen
1. Go to **Nearby** tab (2nd tab)
2. Choose **Bluetooth** or **GPS** discovery mode
3. Tap the scanner to find nearby users
4. Find the user you want to connect with
5. Tap the **green (+) icon** next to their name
6. The icon changes to **"Pending"** (orange)

### From a User's Profile
1. Tap any user's name to open their profile
2. Tap the **"Connect"** button
3. Button changes to **"Pending"**

### What Happens After Sending
- A connection request document is created in Firestore with `status: pending`
- The other user receives a **push notification**: "🤝 [username] wants to connect"
- The request appears in their **Settings → Connection Requests** screen

---

## How to Accept a Connection Request

### Method 1: From Settings
1. Open **Settings** (Profile tab → gear icon, or last tab)
2. Look for **"Connection Requests"** — it shows the count of pending requests
3. Tap it to see all pending requests
4. Each request shows the sender's name, avatar, headline, and the mode (Pro/Social)
5. Tap **"Accept"** to accept or **"Decline"** to reject

### Method 2: From Nearby Screen
1. If you see **"Accept?"** (blue badge) next to a user on the Nearby screen
2. Tap their name to open their profile
3. Tap the **"Accept"** button (green) — this navigates to Connection Requests
4. Accept from there

### Method 3: From a User's Profile
1. Open the user's profile who sent you a request
2. The button shows **"Accept"** (green) instead of "Connect"
3. Tap it — navigates to Connection Requests screen to confirm

### What Happens When You Accept
- Connection status changes to `accepted`
- **Both users automatically follow each other** in the connection's mode
- Both appear in each other's **Connections** list for that mode
- The sender receives a notification: "✅ [username] accepted your request"
- Follower and following counts update in real-time

### What Happens When You Decline
- The connection request is removed
- The sender can re-send a new request later
- No notification is sent for declines

---

## How to View Your Connections, Followers & Following

### From Settings
1. Go to **Settings** screen
2. Under **"Social Stats"**, you see cards for Followers and Following (with counts)
3. Tap **Followers** to see your followers list
4. Tap **Following** to see who you follow
5. The screen has 3 tabs: **Followers | Following | Connections**

### From Your Profile
1. Go to **Profile** tab
2. Tap the **Followers**, **Following**, or **Connections** count
3. Opens the same 3-tab screen

### From Another User's Profile
1. Open any user's profile
2. Tap their Followers, Following, or Connections count
3. View their social graph (you can only manage your own)

> **Note:** Stats are mode-specific. Switch between Pro and Social mode to see different counts.

---

## How to Remove a Connection

### From the Connections Tab (Followers/Following Screen)
1. Go to **Settings → Followers** (or tap Connections count on profile)
2. Switch to the **Connections** tab
3. Find the user you want to disconnect
4. Tap **"Remove"** (red text)
5. Confirm in the dialog

### From the Connections Screen
1. Go to **Connections** screen (accessible from Settings → Connection Requests → back)
2. Tap the **⋮** menu on any connection
3. Choose **"Remove Connection"**
4. Confirm

### From a User's Profile
1. Open the connected user's profile
2. The button shows **"Connected ▼"**
3. Tap it → choose **"Remove"**
4. Confirm

### What Happens When You Remove
- Connection document is deleted
- **Both users are mutually unfollowed** in that mode
- Both disappear from each other's Connections list
- Follower/following counts decrease
- Either user can send a new request later

---

## How to Remove a Follower

1. Go to **Settings → Followers** (or tap Followers count on profile)
2. Stay on the **Followers** tab
3. Find the follower you want to remove
4. Tap **"Remove"** (red text)
5. Confirm in the dialog

### What Happens
- If there's a connection, the connection is deleted (mutual unfollow)
- If there's no connection, the user is removed from your followers list directly

---

## How to Unfollow Someone

1. Go to **Settings → Following** (or tap Following count on profile)
2. Switch to the **Following** tab
3. Find the user you want to unfollow
4. Tap **"Unfollow"** (orange text)
5. Confirm in the dialog

### What Happens
- If there's a connection, the connection is deleted (mutual unfollow)
- If there's no connection, you're removed from their followers and they from your following

---

## Mode-Specific Behavior

Proxi maintains **separate social graphs for Pro and Social modes**:

| Action | Pro Mode | Social Mode |
|--------|----------|-------------|
| Send connection request | Tagged as `formal` | Tagged as `casual` |
| Accept request | Follow each other in Pro | Follow each other in Social |
| View followers | Shows Pro followers only | Shows Social followers only |
| View connections | Shows Pro connections only | Shows Social connections only |

### Cross-Mode Visibility
- Connection **requests** are visible in **all modes** — if someone sends you a Pro request while you're in Social mode, you'll still see it in Connection Requests
- Connection **lists** are filtered by current mode
- Follower/following **counts** are mode-specific

---

## Quick Reference

| I want to... | How |
|-------------|-----|
| Connect with someone | Nearby → scan → tap (+) icon, or Profile → Connect |
| Accept a request | Settings → Connection Requests → Accept |
| See my followers | Settings → Followers card, or Profile → tap count |
| Remove a follower | Followers tab → Remove |
| Unfollow someone | Following tab → Unfollow |
| Remove a connection | Connections tab → Remove, or user Profile → Connected ▼ → Remove |
| Re-connect after removing | Find them on Nearby or their Profile → Connect |

---

## Troubleshooting

| Issue | Solution |
|-------|---------|
| Can't see connection request | Both users must be signed in. Check **Settings → Connection Requests** (requests show across all modes). |
| "Pending" stuck | The other user hasn't responded yet. They need to check their Connection Requests. |
| Followers count wrong after mode switch | Counts are mode-specific. Toggle mode to see the correct numbers. |
| Remove not working | Make sure you have internet connection. The app needs to update both users' data in Firestore. |
| Duplicate entries | If you see duplicates, the same user may appear from different connection modes. |

---

**Built with Flutter + Firebase** | **Proxi 2.0** | **Last Updated: February 2026**
