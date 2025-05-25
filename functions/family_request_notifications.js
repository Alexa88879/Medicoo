// functions/family_request_notifications.js
// const admin = require("firebase-admin");
const {sendNotification}= require("./notifications");
const onFamilyRequestCreateHandler = async (snapshot, context) =>{
  const requestData = snapshot.data();
  const requestId = context.params.requestId;

  if (!requestData) {
    console.log("No data in family request.");
    return null;
  }

  const recipientId = requestData.recipientId; // User receiving the request
  const senderName = requestData.senderName || "Someone"; // Name of user sending request

  if (!recipientId) {
    console.error("Recipient ID missing in family request.");
    return null;
  }

  /** @type {import('./notifications').NotificationPayload} */
  const payload = {
    userId: recipientId,
    title: "Family Member Request",
    body: `${senderName} has sent you a family member request.`,
    type: "FAMILY_REQUEST_RECEIVED",
    relatedDocId: requestId,
    relatedCollection: "familyRequests",
    data: {screen: "/familyRequests", id: requestId},
  };

  await sendNotification(payload);
  return null;
};

// You might also want an onUpdate for familyRequests if you want to notify
// the sender when a request is accepted/rejected.
// e.g., exports.onFamilyRequestUpdate = functions.firestore.document("familyRequests/{requestId}").onUpdate(async (change, context) => {
//   const newData = change.after.data();
//   const oldData = change.before.data(); // If needed to check previous status
//   if (newData.status === 'accepted' && newData.status !== oldData.status) {
//     // Assuming senderId and recipientName are stored in requestData
//     const senderId = newData.senderId;
//     const recipientName = newData.recipientName || "A user";
//     if (senderId) {
//       await sendNotification({
//         userId: senderId,
//         title: "Request Accepted",
//         body: `Your family member request to ${recipientName} has been accepted.`,
//         type: "FAMILY_REQUEST_ACCEPTED",
//         relatedDocId: context.params.requestId,
//         relatedCollection: "familyRequests",
//         data: { screen: "/familyRequests", id: context.params.requestId }, // Or navigate to the family member's profile
//       });
//     }
//   }
//   // Add similar logic for 'rejected' status if needed
//   return null;
// });

module.exports = {
  onFamilyRequestCreateHandler,
  // If you implement onFamilyRequestUpdate, export it here as well:
  // onFamilyRequestUpdate: onFamilyRequestUpdate // (if you uncomment and create the handler)
};
