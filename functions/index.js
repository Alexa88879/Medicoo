// functions/index.js
const admin = require("firebase-admin");
const functions = require("firebase-functions");
admin.initializeApp();

const notifications = require("./notifications");
const appointmentNotifications = require("./appointment_notifications");
const familyRequestNotifications = require("./family_request_notifications");
const scheduledDosageReminders = require("./scheduled_dosage_reminders"); // Your updated file

// --- HTTP Triggers ---
exports.sendTestNotification = functions.https.onCall(
  notifications.sendTestNotificationHandler,
);

// --- Firestore Triggers ---
exports.onAppointmentUpdate = functions.firestore
  .onDocumentUpdated("appointments/{appointmentId}", appointmentNotifications.onAppointmentUpdateHandler);

exports.onFamilyRequestCreate = functions.firestore
  .onDocumentCreated("familyRequests/{requestId}", familyRequestNotifications.onFamilyRequestCreateHandler);

// --- Scheduled Functions (Pub/Sub Triggers) ---
// For Dosage Reminders
exports.scheduledDosageReminders = functions.scheduler.onSchedule(
  "*/15 * * * *", // Run every 15 minutes
  scheduledDosageReminders.checkDosageRemindersHandler,
);

// For Appointment Reminders (Implement handler similarly)
exports.scheduledAppointmentReminders = functions.scheduler.onSchedule(
  "0 * * * *", // Run every hour
  async (_context) => {
    console.log("Scheduled Appointment Reminder Function: Checking...");
    const now = admin.firestore.Timestamp.now();
    const reminderWindowStart = admin.firestore.Timestamp.fromMillis(now.toMillis() + 23 * 60 * 60 * 1000); // Approx 23 hours from now
    const reminderWindowEnd = admin.firestore.Timestamp.fromMillis(now.toMillis() + 25 * 60 * 60 * 1000); // Approx 25 hours from now (for a 24-hour reminder)

    // Add another window for, e.g., 1-hour reminder
    // const oneHourReminderStart = admin.firestore.Timestamp.fromMillis(now.toMillis() + 55 * 60 * 1000);
    // const oneHourReminderEnd = admin.firestore.Timestamp.fromMillis(now.toMillis() + 65 * 60 * 1000);


    try {
      const appointmentsSnapshot = await admin.firestore().collection("appointments")
        .where("status", "in", ["booked", "confirmed", "video_link_added"]) // Active appointments
        .where("dateTimeFull", ">=", reminderWindowStart)
        .where("dateTimeFull", "<=", reminderWindowEnd)
        // Add .where("isReminderSent_24h", "==", false) if you add such a flag
        .get();

      if (appointmentsSnapshot.empty) {
        console.log("No upcoming appointments for 24-hour reminder.");
        // Query for 1-hour reminders separately or combine logic
        return null;
      }

      const promises = [];
      appointmentsSnapshot.forEach((doc) => {
        const appointment = {id: doc.id, ...doc.data()};
        console.log(`Sending 24-hour reminder for appointment ${appointment.id} to user ${appointment.userId}`);
        promises.push(
          notifications.sendNotification({
            userId: appointment.userId,
            title: "Appointment Reminder",
            body: `Your appointment with Dr. ${appointment.doctorName || "your doctor"} is scheduled for tomorrow around ${appointment.appointmentTime || ""}.`,
            type: "APPOINTMENT_REMINDER_24H",
            relatedDocId: appointment.id,
            relatedCollection: "appointments",
            data: {screen: "/appointmentDetail", id: appointment.id},
          }),
        );
        // Optional: Mark that a 24h reminder has been sent
        // promises.push(doc.ref.update({ isReminderSent_24h: true }));
      });
      await Promise.all(promises);
    } catch (error) {
      console.error("Error sending appointment reminders:", error);
    }
    return null;
  });
