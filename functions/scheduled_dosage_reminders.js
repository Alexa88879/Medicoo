// functions/scheduled_dosage_reminders.js

const admin = require("firebase-admin");
// const functions = require("firebase-functions");
const {sendNotification} = require("./notifications");

const db = admin.firestore();

const checkDosageRemindersHandler = async (_message, _context) => {
  console.log("Checking for dosage reminders...");

  const now = admin.firestore.Timestamp.now();
  // Define a time window, e.g., reminders due in the next 15 minutes
  // This depends on how frequently your Cloud Scheduler job runs.
  // If it runs every 15 mins, check for reminders in that 15-min window.
  const reminderWindowEnd = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + 15 * 60 * 1000, // 15 minutes from now
  );

  try {
    // Query active prescriptions with a reminder time within the window
    // This schema assumes your 'prescriptions' collection has:
    // - userId (String)
    // - medicationName (String)
    // - isActive (Boolean)
    // - nextReminderTime (Timestamp) - THIS IS CRUCIAL for efficient querying

    const prescriptionsSnapshot = await db
      .collectionGroup("prescriptions") // Use collectionGroup if prescriptions are subcollections
      // If prescriptions is a root collection: .collection("prescriptions")
      .where("isActive", "==", true)
      .where("nextReminderTime", ">=", now)
      .where("nextReminderTime", "<=", reminderWindowEnd)
      .get();

    if (prescriptionsSnapshot.empty) {
      console.log("No dosage reminders due.");
      return null;
    }

    const promises = [];
    prescriptionsSnapshot.forEach((doc) => {
      const prescription = doc.data();
      const prescriptionId = doc.id;

      if (!prescription.userId || !prescription.medicationName) {
        console.warn(`Skipping prescription ${prescriptionId} due to missing data.`);
        return; // continue to next iteration
      }

      console.log(
        `Sending dosage reminder for ${prescription.medicationName} to user ${prescription.userId}`,
      );

      const notificationPromise = sendNotification({
        userId: prescription.userId,
        title: "Medication Reminder",
        body: `It's time to take your ${prescription.medicationName}.`,
        type: "DOSAGE_REMINDER",
        relatedDocId: prescriptionId,
        relatedCollection: "prescriptions", // or the full path if subcollection
        data: {screen: "/prescriptionDetail", id: prescriptionId},
      });
      promises.push(notificationPromise);

      // IMPORTANT: Update the nextReminderTime for this prescription
      const newNextReminderTime = calculateNextReminder(prescription);
      if (newNextReminderTime) {
        promises.push(doc.ref.update({nextReminderTime: newNextReminderTime}));
      } else {
        promises.push(doc.ref.update({isActive: false}));
        console.log(`Deactivated prescription ${prescriptionId} after final reminder.`);
      }
    });

    await Promise.all(promises);
  } catch (error) {
    console.error("Error processing dosage reminders:", error);
  }

  return null;
};

/**
 * Placeholder: You MUST implement this based on your prescription schedule logic.
 * @param {admin.firestore.DocumentData} prescription The prescription data.
 * @returns {admin.firestore.Timestamp | null} The next Timestamp for the reminder, or null if no more reminders.
 */
function calculateNextReminder(prescription) {
  // EXAMPLE LOGIC (VERY SIMPLIFIED - REPLACE WITH YOUR ACTUAL LOGIC)
  // If it's a daily medication, add 24 hours to the current nextReminderTime.
  // If it's "take once", this might return null.
  // If it's "3 times a day", you'll need more complex logic.
  // Consider prescription.frequency, prescription.interval, prescription.endDate etc.
  if (prescription.nextReminderTime && prescription.frequency === "daily") {
    return admin.firestore.Timestamp.fromMillis(
      prescription.nextReminderTime.toMillis() + 24 * 60 * 60 * 1000,
    );
  }
  // For more complex schedules (e.g., "every 6 hours for 7 days"), you'll need to store
  // the start date, duration, interval, and calculate accordingly.
  // This might involve checking if the prescription duration has ended.
  console.warn(
    `'calculateNextReminder' needs to be properly implemented for prescription ${prescription.id || "unknown"}`,
  );
  return null;
}

module.exports = {
  checkDosageRemindersHandler,
};
