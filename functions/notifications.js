// functions/notifications.js

const admin = require("firebase-admin");
const functions = require("firebase-functions"); // For HttpsError and potentially logger

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Sends a notification via FCM and stores it in Firestore.
 * @param {object} payload The notification data.
 * @param {string} payload.userId UID of the target user.
 * @param {string} payload.title Notification title.
 * @param {string} payload.body Notification body.
 * @param {string} payload.type Notification type (e.g., APPOINTMENT_CONFIRMED).
 * @param {string} [payload.relatedDocId] Optional ID of related Firestore doc.
 * @param {string} [payload.relatedCollection] Optional collection of related doc.
 * @param {object} [payload.data] Optional data payload for client app (e.g., {screen: "/details", id: "123"}).
 * @return {Promise<void>} A promise that resolves when the operation is complete.
 */
async function sendNotification(payload) {
  const {userId, title, body, type, relatedDocId, relatedCollection, data} = payload;

  console.log(`Attempting to send notification to user ${userId}`);
  console.log("Notification payload:", payload);

  try {
    // Get the user's FCM tokens
    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();
    const fcmTokens = userData?.fcmTokens || [];

    if (!fcmTokens.length) {
      console.error(`No FCM tokens found for user ${userId}`);
      return;
    }

    console.log(`Found ${fcmTokens.length} FCM tokens for user ${userId}`);

    // Send to all tokens
    const sendPromises = fcmTokens.map((fcmToken) => {
      const message = {
        token: fcmToken,
        notification: {
          title,
          body,
        },
        data: {
          type,
          ...(relatedDocId && {docId: relatedDocId}),
          ...(relatedCollection && {collection: relatedCollection}),
          ...(data && {...data}),
        },
      };
      return messaging.send(message)
        .catch((error) => {
          if (error.code === "messaging/registration-token-not-registered") {
            // Token is invalid, remove it from the user's tokens
            return db.collection("users").doc(userId).update({
              fcmTokens: admin.firestore.FieldValue.arrayRemove(fcmToken),
            });
          }
          throw error;
        });
    });

    const responses = await Promise.all(sendPromises);
    console.log("Successfully sent messages:", responses);

    // Store the notification in Firestore
    await db.collection("users").doc(userId)
      .collection("notifications")
      .add({
        title,
        body,
        type,
        relatedDocId,
        relatedCollection,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
      });

    console.log("Notification stored in Firestore");
  } catch (error) {
    console.error("Error sending notification:", error);
    throw error;
  }
}

/**
 * Handles HTTP callable requests to send a test notification.
 * @param {object} data Data passed to the function from the client.
 * @param {functions.https.CallableContext} context Context of the call, including auth.
 * @return {Promise<{success: boolean, message: string}>} Result of the operation.
 */
const sendTestNotificationHandler = async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to send a test notification.",
    );
  }
  const userId = context.auth.uid;
  const {title, body, type, relatedDocId, relatedCollection, customData} = data;

  if (!title || !body || !type) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Request must include title, body, and type for the notification.",
    );
  }

  console.log(`Test notification requested by user ${userId} with type ${type}`);
  await sendNotification({
    userId,
    title,
    body,
    type,
    relatedDocId: relatedDocId, // Can be undefined
    relatedCollection: relatedCollection, // Can be undefined
    data: customData, // This is where { screen: "...", id: "..." } should be passed
  });

  return {success: true, message: "Test notification processed."};
};

module.exports = {
  sendNotification,
  sendTestNotificationHandler,
};

// functions/appointment_notifications.js

// const functions = require("firebase-functions"); // Not strictly needed if only exporting a handler

/**
 * Handles Firestore onUpdate triggers for the 'appointments' collection.
 * Sends notifications for status changes or video link additions.
 * @param {functions.Change<functions.firestore.DocumentSnapshot>} change
 * The change object containing before and after snapshots.
 * @param {functions.EventContext} context The event context.
 * @return {Promise<null>} A promise that resolves when processing is complete.
 */
const onAppointmentUpdateHandler = async (change, context) => {
  const appointmentId = context.params.appointmentId;
  const newData = change.after.data();
  const oldData = change.before.data();

  if (!newData || !oldData) {
    console.log("No data found in appointment update for ID:", appointmentId);
    return null;
  }

  const userId = newData.userId;
  const doctorName = newData.doctorName || "your doctor";

  let notificationDetails = null;
  let sendThisNotification = false;

  // Check for status changes
  if (newData.status !== oldData.status) {
    sendThisNotification = true; // A status change warrants a notification
    switch (newData.status) {
    case "confirmed":
      notificationDetails = {
        title: "Appointment Confirmed!",
        body: `Your appointment with Dr. ${doctorName} has been confirmed.`,
        type: "APPOINTMENT_CONFIRMED",
      };
      break;
    case "cancelled":
      notificationDetails = {
        title: "Appointment Cancelled",
        body: `Your appointment with Dr. ${doctorName} has been cancelled.`,
        type: "APPOINTMENT_CANCELLED",
      };
      break;
    // Add other status cases if needed, e.g., "rescheduled"
    default:
      sendThisNotification = false; // Don't send for unhandled status changes
      console.log(`Unhandled status change from ${oldData.status} to ${newData.status} for appointment ${appointmentId}.`);
    }
  }

  // Check for video link addition
  // If a video link is added, we might want to send this notification
  // even if the status didn't change, or combine it.
  // Current logic: This will override the status change notification if both happen in the same update.
  if (newData.videoLink && newData.videoLink !== oldData.videoLink) {
    notificationDetails = { // This will be the notification sent if videoLink changes
      title: "Video Link Added",
      body: `Dr. ${doctorName} has added a video link for your upcoming appointment.`,
      type: "APPOINTMENT_VIDEO_LINK_ADDED",
    };
    sendThisNotification = true;
  }

  if (sendThisNotification && notificationDetails && userId) {
    console.log(
      `Sending ${notificationDetails.type} notification for appointment ${appointmentId} to user ${userId}`,
    );
    await sendNotification({
      userId: userId,
      title: notificationDetails.title,
      body: notificationDetails.body,
      type: notificationDetails.type,
      relatedDocId: appointmentId,
      relatedCollection: "appointments",
      data: {screen: "/appointmentDetail", id: appointmentId}, // For client-side navigation
    });
  } else if (sendThisNotification && notificationDetails && !userId) {
    console.warn(
      `Cannot send notification for appointment ${appointmentId}: userId is missing.`,
    );
  }
  return null;
};

module.exports = {
  onAppointmentUpdateHandler,
};

// functions/family_request_notifications.js

// const functions = require("firebase-functions"); // Not strictly needed

/**
 * Handles Firestore onCreate triggers for the 'familyRequests' collection.
 * Sends a notification to the recipient of the family request.
 * @param {functions.firestore.DocumentSnapshot} snapshot The snapshot of the created document.
 * @param {functions.EventContext} context The event context.
 * @return {Promise<null>} A promise that resolves when processing is complete.
 */
const onFamilyRequestCreateHandler = async (snapshot, context) => {
  const requestData = snapshot.data();
  const requestId = context.params.requestId;

  if (!requestData) {
    console.log("No data in family request for ID:", requestId);
    return null;
  }

  const recipientId = requestData.recipientId; // User receiving the request
  const senderName = requestData.senderName || "Someone"; // Name of user sending request

  if (!recipientId) {
    console.error("Recipient ID missing in family request:", requestId);
    return null;
  }

  console.log(
    `Sending FAMILY_REQUEST_RECEIVED notification for request ${requestId} to user ${recipientId}`,
  );

  // Type definition for JSDoc, actual NotificationPayload is in notifications.js
  /** @type {import('./notifications').NotificationPayload} */
  const payload = {
    userId: recipientId,
    title: "Family Member Request",
    body: `${senderName} has sent you a family member request.`,
    type: "FAMILY_REQUEST_RECEIVED",
    relatedDocId: requestId,
    relatedCollection: "familyRequests",
    data: {screen: "/familyRequests", id: requestId}, // For client-side navigation
  };

  await sendNotification(payload);
  return null;
};

// TODO: Consider adding an onUpdate handler for familyRequests
// to notify the sender when a request is accepted or declined.
// exports.onFamilyRequestUpdate = functions.firestore
//   .document("familyRequests/{requestId}")
//   .onUpdate(async (change, context) => { ... });

module.exports = {
  onFamilyRequestCreateHandler,
};

// functions/scheduled_dosage_reminders.js
// admin is used for Firestore Timestamp and db access
// const functions = require("firebase-functions"); // Not strictly needed if only exporting a handler

/**
 * Cloud Function triggered by Pub/Sub to check for and send dosage reminders.
 * @param {functions.pubsub.Message} _message The Pub/Sub message (often unused for simple schedules).
 * @param {functions.EventContext} _context The event context.
 * @return {Promise<null>} A promise that resolves when processing is complete.
 */
const checkDosageRemindersHandler = async (_message, _context) => {
  console.log("Checking for dosage reminders...");

  const now = admin.firestore.Timestamp.now();
  // Define a time window for reminders. Example: reminders due in the next 15 minutes.
  // This window should align with how frequently your Cloud Scheduler job runs.
  const reminderWindowEnd = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + 15 * 60 * 1000, // 15 minutes from now
  );

  try {
    // Query active prescriptions with a 'nextReminderTime' within the current window.
    // Assumes 'prescriptions' collection has:
    // - userId (String)
    // - medicationName (String)
    // - isActive (Boolean)
    // - nextReminderTime (Timestamp) - CRUCIAL for efficient querying
    const prescriptionsSnapshot = await db
      .collectionGroup("prescriptions") // Use collectionGroup if prescriptions are subcollections
      // If 'prescriptions' is a root collection: .collection("prescriptions")
      .where("isActive", "==", true)
      .where("nextReminderTime", ">=", now)
      .where("nextReminderTime", "<=", reminderWindowEnd)
      .get();

    if (prescriptionsSnapshot.empty) {
      console.log("No dosage reminders due in this window.");
      return null;
    }

    const promises = [];
    prescriptionsSnapshot.forEach((doc) => {
      const prescription = doc.data();
      const prescriptionId = doc.id;

      if (!prescription.userId || !prescription.medicationName) {
        console.warn(
          `Skipping prescription ${prescriptionId} due to missing userId or medicationName.`,
        );
        return; // Skips this iteration of forEach
      }

      console.log(
        `Preparing dosage reminder for ${prescription.medicationName} to user ${prescription.userId}`,
      );

      const notificationPromise = sendNotification({
        userId: prescription.userId,
        title: "Medication Reminder",
        body: `It's time to take your ${prescription.medicationName}.`,
        type: "DOSAGE_REMINDER",
        relatedDocId: prescriptionId,
        relatedCollection: "prescriptions", // Or the full path if it's a subcollection
        data: {screen: "/prescriptionDetail", id: prescriptionId}, // For client-side navigation
      });
      promises.push(notificationPromise);

      // IMPORTANT: Update the nextReminderTime for this prescription.
      const newNextReminderTime = calculateNextReminder(prescription);
      if (newNextReminderTime) {
        promises.push(
          doc.ref.update({nextReminderTime: newNextReminderTime}),
        );
      } else {
        // If no next reminder time (e.g., prescription course finished), deactivate it.
        promises.push(doc.ref.update({isActive: false}));
        console.log(
          `Deactivated prescription ${prescriptionId} as no next reminder time could be calculated.`,
        );
      }
    });

    await Promise.all(promises);
    // Each reminder generates two promises (sendNotification and Firestore update)
    console.log(`Processed ${prescriptionsSnapshot.docs.length} dosage reminders.`);
  } catch (error) {
    console.error("Error processing dosage reminders:", error);
    // Depending on the error, you might want to implement more specific error handling or retries.
  }
  return null;
};

/**
 * Calculates the next reminder time based on prescription details.
 * IMPORTANT: This is a placeholder and needs robust implementation
 * based on your specific prescription scheduling logic (e.g., daily,
 * X times a day at specific hours, specific days of the week, start/end dates, etc.).
 * @param {admin.firestore.DocumentData} prescription The prescription data from Firestore.
 * @return {admin.firestore.Timestamp | null} The next Timestamp for the reminder,
 * or null if no more reminders are due for this prescription.
 */
function calculateNextReminder(prescription) {
  // --- THIS IS A VERY SIMPLIFIED EXAMPLE ---
  // --- YOU MUST REPLACE THIS WITH YOUR ACTUAL PRESCRIPTION LOGIC ---

  // Example: If prescription has a 'frequency' field and it's 'daily'
  if (prescription.nextReminderTime && prescription.frequency === "daily") {
    const currentReminder = prescription.nextReminderTime.toDate(); // Convert Firestore Timestamp to JS Date
    const nextReminderDate = new Date(currentReminder.getTime());
    nextReminderDate.setDate(currentReminder.getDate() + 1); // Add one day

    // Optional: Check against an 'endDate' if your prescriptions have one
    if (prescription.endDate && prescription.endDate.toDate() < nextReminderDate) {
      console.log(`Prescription ${prescription.id || "unknown"} has ended. No next reminder.`);
      return null; // Prescription period has ended
    }
    return admin.firestore.Timestamp.fromDate(nextReminderDate);
  }

  // Example: If frequency is "every_6_hours"
  if (prescription.nextReminderTime && prescription.frequency === "every_6_hours") {
    const currentReminder = prescription.nextReminderTime.toDate();
    const nextReminderDate = new Date(currentReminder.getTime() + 6 * 60 * 60 * 1000); // Add 6 hours
    // Check against endDate
    if (prescription.endDate && prescription.endDate.toDate() < nextReminderDate) {
      return null;
    }
    return admin.firestore.Timestamp.fromDate(nextReminderDate);
  }

  // Add more conditions for other frequencies: "weekly", "X times a day at specific hours"
  // If it's "X times a day", you'll need to store the specific times (e.g., ["08:00", "14:00", "20:00"])
  // or an interval and calculate the next one based on the current time and those stored times.

  console.warn(
    `'calculateNextReminder' needs to be properly implemented for prescription ID: ${
      prescription.id || "unknown" // Assuming prescription doc has an 'id' field or use doc.id
    }. Current frequency: ${prescription.frequency}`,
  );
  return null; // Return null if no more reminders or logic not implemented for this frequency
}

module.exports = {
  checkDosageRemindersHandler,
};
