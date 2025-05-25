// functions/scheduled_dosage_reminders.js

const admin = require("firebase-admin");
// const functions = require("firebase-functions"); // Not strictly needed if only exporting a handler

// Assuming admin.initializeApp() is called in index.js
const db = admin.firestore();
const {sendNotification} = require("./notifications"); // Ensure this path is correct

/**
 * Calculates the next reminder time based on prescription details.
 * @param {admin.firestore.DocumentData} prescription The prescription data from Firestore.
 * @param {admin.firestore.Timestamp} currentReminderTime The timestamp of the reminder that was just processed.
 * @return {admin.firestore.Timestamp | null} The next Timestamp for the reminder, or null if no more reminders.
 */
function calculateNextReminderTime(prescription, currentReminderTime) {
  if (!prescription.isActive || !prescription.frequency || !prescription.startDate) {
    console.log(`Prescription ${prescription.id || "unknown"} is inactive or missing frequency/startDate.`);
    return null;
  }

  const now = new Date(); // Current server time
  // Remove the unused _startDate line
  const endDate = prescription.endDate ? prescription.endDate.toDate() : null;
  let nextReminder = currentReminderTime.toDate(); // Start from the reminder that was just sent

  // If nextReminder is already in the past (e.g., due to function delay or initial setup),
  // advance it to the next valid slot starting from 'now'.
  // This is a complex part and needs careful handling of different frequencies.
  // For simplicity in this example, we'll advance based on the last sent reminder.

  if (endDate && nextReminder >= endDate) {
    console.log(`Prescription ${prescription.id || "unknown"} course ended or next reminder past end date.`);
    return null; // Course ended
  }

  switch (prescription.frequency.toLowerCase()) {
  case "daily_morning": // Assume a fixed time like 8 AM
  case "daily_noon": // Assume 12 PM
  case "daily_evening": // Assume 8 PM
  case "daily_bedtime": // Assume 10 PM
    nextReminder.setDate(nextReminder.getDate() + 1);
    // For specific daily times, you'd set the hour/minute here based on the case
    // e.g., if "daily_morning", setHours(8,0,0,0). This example just adds a day.
    break;

  case "twice_a_day_custom": // e.g., ["08:00", "20:00"]
  case "thrice_a_day_custom": // e.g., ["08:00", "14:00", "20:00"]
    if (prescription.reminderTimes && prescription.reminderTimes.length > 0) {
      const sortedTimes = prescription.reminderTimes.sort(); // HH:mm format
      const currentReminderHHMM = `${String(currentReminderTime.toDate().getHours()).padStart(2, "0")}:${String(currentReminderTime.toDate().getMinutes()).padStart(2, "0")}`;

      let foundNext = false;
      // Find next time slot on the same day
      for (const timeStr of sortedTimes) {
        if (timeStr > currentReminderHHMM) {
          const [hours, minutes] = timeStr.split(":").map(Number);
          nextReminder.setHours(hours, minutes, 0, 0);
          foundNext = true;
          break;
        }
      }
      // If no more slots today, take the first slot of tomorrow
      if (!foundNext) {
        nextReminder.setDate(nextReminder.getDate() + 1);
        const [hours, minutes] = sortedTimes[0].split(":").map(Number);
        nextReminder.setHours(hours, minutes, 0, 0);
      }
    } else {
      console.warn(`Custom times frequency for ${prescription.id} but no reminderTimes array.`);
      return null; // Cannot calculate
    }
    break;

  case "every_6_hours":
    nextReminder = new Date(nextReminder.getTime() + 6 * 60 * 60 * 1000);
    break;
  case "every_8_hours":
    nextReminder = new Date(nextReminder.getTime() + 8 * 60 * 60 * 1000);
    break;
  case "every_12_hours":
    nextReminder = new Date(nextReminder.getTime() + 12 * 60 * 60 * 1000);
    break;

    // Add more cases for "weekly_monday", "monthly_1st", etc.
    // These would require more complex date manipulation.

  default:
    console.warn(`Unhandled frequency: ${prescription.frequency} for prescription ${prescription.id || "unknown"}`);
    return null;
  }

  if (endDate && nextReminder >= endDate) {
    console.log(`Calculated next reminder for ${prescription.id} is past end date.`);
    return null; // Course ended
  }
  if (nextReminder <= now) {
    // If calculated next reminder is still in past (e.g. initial setup for an old prescription)
    // This needs more sophisticated logic to "catch up" or start from the next valid slot from 'now'.
    // For now, we'll just log and potentially return null or advance further.
    // A robust solution might involve finding the first valid slot >= now.
    console.warn(`Calculated next reminder for ${prescription.id} is still in the past: ${nextReminder}. Needs catch-up logic.`);
    // Simplistic catch-up: try advancing again by one cycle of its frequency (this is not perfect)
    // return calculateNextReminderTime({ ...prescription, startDate: admin.firestore.Timestamp.fromDate(now) }, admin.firestore.Timestamp.fromDate(now));
    return null; // Or handle catch-up more gracefully
  }

  return admin.firestore.Timestamp.fromDate(nextReminder);
}


const checkDosageRemindersHandler = async (_message, _context) => {
  console.log("Scheduled Dosage Reminder Function: Checking for reminders...");

  const now = admin.firestore.Timestamp.now();
  // Query for prescriptions where nextReminderTime is due (e.g., within the next 5 minutes to catch recently due)
  // And also slightly in the past (e.g., 15 mins) to catch any missed by previous runs due to small delays.
  // The scheduler should run frequently (e.g., every 5-15 minutes).
  const queryWindowStart = admin.firestore.Timestamp.fromMillis(now.toMillis() - 15 * 60 * 1000); // 15 mins ago
  const queryWindowEnd = admin.firestore.Timestamp.fromMillis(now.toMillis() + 5 * 60 * 1000); // 5 mins from now

  try {
    const prescriptionsSnapshot = await db
      .collection("prescriptions") // Assuming 'prescriptions' is a root collection
      .where("isActive", "==", true)
      .where("nextReminderTime", ">=", queryWindowStart)
      .where("nextReminderTime", "<=", queryWindowEnd)
      .get();

    if (prescriptionsSnapshot.empty) {
      console.log("No dosage reminders due in the current window.");
      return null;
    }

    const promises = [];
    prescriptionsSnapshot.forEach((doc) => {
      const prescription = {id: doc.id, ...doc.data()}; // Include doc.id for logging

      // Prevent re-sending if lastReminderSentAt is too recent for this specific nextReminderTime
      if (prescription.lastReminderSentAt && prescription.nextReminderTime &&
          prescription.lastReminderSentAt.seconds === prescription.nextReminderTime.seconds) {
        console.log(`Reminder for prescription ${prescription.id} at ${prescription.nextReminderTime.toDate()} already processed (based on lastReminderSentAt). Skipping.`);
        // Still calculate next reminder time to keep schedule advancing if needed
        const nextDue = calculateNextReminderTime(prescription, prescription.nextReminderTime);
        if (nextDue) {
          promises.push(doc.ref.update({nextReminderTime: nextDue, isActive: true}));
        } else {
          promises.push(doc.ref.update({isActive: false, nextReminderTime: null}));
          console.log(`Deactivated prescription ${prescription.id} as no further reminders are due.`);
        }
        return; // Skip to next prescription
      }


      console.log(
        `Sending dosage reminder for ${prescription.medicationName || prescription.medications?.[0]?.medicineName || "medication"} to user ${prescription.patientId}`,
      );

      const notificationPromise = sendNotification({
        userId: prescription.patientId, // Ensure this field exists and is the user's UID
        title: "Medication Reminder",
        body: `Time for your ${prescription.medicationName || prescription.medications?.[0]?.medicineName || "medication"}.`,
        type: "DOSAGE_REMINDER",
        relatedDocId: prescription.id,
        relatedCollection: "prescriptions",
        data: {screen: "/prescriptionDetail", id: prescription.id}, // Navigate to prescription detail
      });
      promises.push(notificationPromise);

      const newNextReminderTime = calculateNextReminderTime(prescription, prescription.nextReminderTime);
      const updatePayload = {
        lastReminderSentAt: prescription.nextReminderTime, // Mark this reminder time as processed
      };

      if (newNextReminderTime) {
        updatePayload.nextReminderTime = newNextReminderTime;
        updatePayload.isActive = true; // Ensure it remains active
        console.log(`Prescription ${prescription.id}: Next reminder set to ${newNextReminderTime.toDate()}`);
      } else {
        updatePayload.isActive = false;
        updatePayload.nextReminderTime = null; // Clear it if no more reminders
        console.log(`Prescription ${prescription.id}: Deactivated, no further reminders.`);
      }
      promises.push(doc.ref.update(updatePayload));
    });

    await Promise.all(promises);
    console.log(`Processed ${prescriptionsSnapshot.docs.length} dosage reminders.`);
  } catch (error) {
    console.error("Error processing dosage reminders:", error);
  }
  return null;
};

module.exports = {
  checkDosageRemindersHandler,
};
