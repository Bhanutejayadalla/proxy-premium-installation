/**
 * Firebase Cloud Functions for Proxi — Push Notifications
 *
 * Triggers:
 * 1. onNewNotification — sends FCM push when a notification doc is created
 * 2. onNewMessage — sends FCM push when a chat message is created
 * 3. onNewGroupMessage — sends FCM push for group chat messages
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ─────────────────────────────────────────────
//  1. Push notification when a notification doc is created
// ─────────────────────────────────────────────
exports.onNewNotification = onDocumentCreated(
  "notifications/{notifId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const userId = data.user_id;
    const fromUsername = data.from_username || "Someone";
    const type = data.type || "notification";
    const text = data.text || "";

    // Get target user's FCM token
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) return;
    const fcmToken = userDoc.data().fcm_token;
    if (!fcmToken) return;

    // Build notification
    let title = "Proxi";
    let body = text;

    switch (type) {
      case "like":
        title = `${fromUsername} liked your post`;
        body = text;
        break;
      case "comment":
        title = `${fromUsername}`;
        body = text;
        break;
      case "connection_request":
        title = "New Connection Request";
        body = `${fromUsername} ${text}`;
        break;
      case "message":
        title = `${fromUsername}`;
        body = text;
        break;
      default:
        title = fromUsername;
        body = text;
    }

    try {
      await getMessaging().send({
        token: fcmToken,
        notification: { title, body },
        data: {
          type,
          from_uid: data.from_uid || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "proxi_main",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: { sound: "default", badge: 1 },
          },
        },
      });
    } catch (err) {
      console.error("FCM send failed:", err);
      // Clean up invalid tokens
      if (
        err.code === "messaging/invalid-registration-token" ||
        err.code === "messaging/registration-token-not-registered"
      ) {
        await db.collection("users").doc(userId).update({ fcm_token: "" });
      }
    }
  }
);

// ─────────────────────────────────────────────
//  2. Push on new DM message
// ─────────────────────────────────────────────
exports.onNewMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const senderUid = data.sender_uid;
    const senderUsername = data.sender_username || "Someone";
    const text = data.text || "";
    const fileType = data.file_type;

    // Get chat doc to find the other participant
    const chatDoc = await db.collection("chats").doc(event.params.chatId).get();
    if (!chatDoc.exists) return;

    const participants = chatDoc.data().participants || [];
    const receiverUid = participants.find((p) => p !== senderUid);
    if (!receiverUid) return;

    // Get receiver's FCM token
    const receiverDoc = await db.collection("users").doc(receiverUid).get();
    if (!receiverDoc.exists) return;
    const fcmToken = receiverDoc.data().fcm_token;
    if (!fcmToken) return;

    const body = fileType ? `Sent a ${fileType}` : text;

    try {
      await getMessaging().send({
        token: fcmToken,
        notification: {
          title: senderUsername,
          body: body || "New message",
        },
        data: {
          type: "message",
          chat_id: event.params.chatId,
          sender_uid: senderUid,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "proxi_main",
            sound: "default",
          },
        },
      });
    } catch (err) {
      console.error("FCM DM send failed:", err);
    }
  }
);

// ─────────────────────────────────────────────
//  3. Push on new group chat message
// ─────────────────────────────────────────────
exports.onNewGroupMessage = onDocumentCreated(
  "group_chats/{groupId}/messages/{messageId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const senderUid = data.sender_uid;
    const senderUsername = data.sender_username || "Someone";
    const text = data.text || "";
    const fileType = data.file_type;

    // Get group doc for members and name
    const groupDoc = await db
      .collection("group_chats")
      .doc(event.params.groupId)
      .get();
    if (!groupDoc.exists) return;

    const groupData = groupDoc.data();
    const members = groupData.members || [];
    const groupName = groupData.name || "Group";
    const body = fileType ? `Sent a ${fileType}` : text;

    // Send to all members except sender
    const otherMembers = members.filter((m) => m !== senderUid);

    const sendPromises = otherMembers.map(async (uid) => {
      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists) return;
      const fcmToken = userDoc.data().fcm_token;
      if (!fcmToken) return;

      try {
        await getMessaging().send({
          token: fcmToken,
          notification: {
            title: `${groupName} — ${senderUsername}`,
            body: body || "New message",
          },
          data: {
            type: "group_message",
            group_id: event.params.groupId,
            sender_uid: senderUid,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "proxi_main",
              sound: "default",
            },
          },
        });
      } catch (err) {
        console.error(`FCM group send failed for ${uid}:`, err);
      }
    });

    await Promise.all(sendPromises);
  }
);
