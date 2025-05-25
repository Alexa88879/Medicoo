// functions/index.js
const admin = require("firebase-admin");
const functions = require("firebase-functions"); // Main firebase-functions module
// Initialize Firebase Admin SDK ONCE
admin.initializeApp();

// Import handlers from other modules
const notifications = require("./notifications");
const appointmentNotifications = require("./appointment_notifications");
const familyRequestNotifications = require("./family_request_notifications");
const scheduledDosageReminders = require("./scheduled_dosage_reminders");

// --- HTTP Triggers ---
// Callable function for sending a test notification
exports.sendTestNotification = functions.https.onCall(
  notifications.sendTestNotificationHandler,
);

// --- Firestore Triggers ---
// Trigger for appointment updates
exports.onAppointmentUpdate = functions.firestore
  .onDocumentUpdated("appointments/{appointmentId}", appointmentNotifications.onAppointmentUpdateHandler);

// Trigger for new family requests
exports.onFamilyRequestCreate = functions.firestore
  .onDocumentCreated("familyRequests/{requestId}", familyRequestNotifications.onFamilyRequestCreateHandler);

// --- Scheduled Functions (Pub/Sub Triggers) ---
// Trigger for scheduled dosage reminders
exports.scheduledDosageReminders = functions.pubsub.onMessagePublished(
  "projects/curelink-cb43f/topics/dosage-reminders-tick",
  scheduledDosageReminders.checkDosageRemindersHandler,
);
// Trigger for scheduled appointment reminders (TODO: Implement its handler)
const {onMessagePublished} = require("firebase-functions/v2/pubsub");
exports.scheduledAppointmentReminders = onMessagePublished(
  "projects/curelink-cb43f/topics/appointment-reminders-tick",
  async (_event) => {
    console.log("Checking for upcoming appointment reminders...");
    // TODO: Implement logic to query appointments and send reminders
    // using notifications.sendNotification(...)
    return;
  });


// To deploy:
// 1. Ensure all files have LF line endings.
// 2. Run `npm run lint -- --fix` in the functions directory.
// 3. Manually fix any remaining lint errors (especially max-len).
// 4. Run `firebase deploy --only functions`.
