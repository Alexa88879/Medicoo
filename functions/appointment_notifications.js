// functions/appointment_notifications.js

// const functions = require("firebase-functions");
const {sendNotification} = require("./notifications");
// const _admin = require("firebase-admin"); // Not strictly needed here if only using sendNotification

const onAppointmentUpdateHandler = async (change, context) => {
  const appointmentId = context.params.appointmentId;
  const newData = change.after.data();
  const oldData = change.before.data();

  if (!newData || !oldData) {
    console.log("No data found in appointment update.");
    return null;
  }

  const userId = newData.userId; // Assuming you have userId in appointment doc
  const doctorName = newData.doctorName || "your doctor";

  let notificationDetails = null; // Renamed from notificationPayload to avoid confusion

  // Check for status changes
  if (newData.status !== oldData.status) {
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
      // Add other status cases if needed
    }
  }

  // Check for video link addition
  // This logic might override the status change notification if both happen in the same update.
  // Consider if you want to send multiple notifications or combine them.
  if (newData.videoLink && newData.videoLink !== oldData.videoLink) {
    notificationDetails = {
      title: "Video Link Added",
      body: `Dr. ${doctorName} has added a video link for your upcoming appointment.`,
      type: "APPOINTMENT_VIDEO_LINK_ADDED",
    };
  }

  if (notificationDetails && userId) {
    await sendNotification({
      userId: userId,
      title: notificationDetails.title,
      body: notificationDetails.body,
      type: notificationDetails.type,
      relatedDocId: appointmentId,
      relatedCollection: "appointments",
      data: {screen: "/appointmentDetail", id: appointmentId},
    });
  }
  return null;
};

module.exports = {
  onAppointmentUpdateHandler,
};
