// lib/notification_center_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:google_fonts/google_fonts.dart'; // For consistent theming

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  void _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _currentUserId = user.uid;
        });
      }
    } else {
      // This case should ideally not be reached if this screen is accessed
      // only by authenticated users.
      print("NotificationCenter: User not logged in. Cannot fetch notifications.");
      // Consider navigating back or showing a login prompt if appropriate.
    }
  }

  void _handleNotificationTap(BuildContext context, Map<String, dynamic> data) {
    final String? screen = data['screen']?.toString();
    final String? id = data['id']?.toString(); // This is the relatedDocId from FCM data

    if (screen != null && screen.isNotEmpty) {
      if (mounted) {
        try {
          // Ensure the route exists in your MaterialApp routes definition in main.dart
          Navigator.of(context).pushNamed(screen, arguments: id);
          print("Navigating from Notification Center to screen: $screen with ID: $id");
        } catch (e) {
          print("Error navigating from Notification Center: $e. Route '$screen' might be missing or context issue.");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not open notification link: '$screen'.", style: GoogleFonts.poppins())),
          );
        }
      }
    } else {
      print("No screen specified in notification data for navigation from Notification Center.");
    }
  }


  @override
  Widget build(BuildContext context) {
    // Use the theme for AppBar consistent with your main.dart
    final appBarTheme = Theme.of(context).appBarTheme;

    if (_currentUserId == null) {
      // This UI state is when the user ID is still being fetched or is null (e.g., user logged out).
      return Scaffold(
        appBar: AppBar(
          title: Text("Notifications", style: appBarTheme.titleTextStyle ?? GoogleFonts.poppins(color: const Color(0xFF00695C))),
          backgroundColor: appBarTheme.backgroundColor ?? Colors.white,
          elevation: appBarTheme.elevation ?? 1.0,
          iconTheme: appBarTheme.iconTheme ?? const IconThemeData(color: Color(0xFF00695C)),
          leading: IconButton( // Add a back button
            icon: Icon(Icons.arrow_back, color: appBarTheme.iconTheme?.color ?? const Color(0xFF00695C)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
            child: FirebaseAuth.instance.currentUser == null // Check auth state directly for the message
                ? Text("Please log in to see notifications.", style: GoogleFonts.poppins())
                : const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Notifications", style: appBarTheme.titleTextStyle ?? GoogleFonts.poppins(color: const Color(0xFF00695C))),
        backgroundColor: appBarTheme.backgroundColor ?? Colors.white,
        elevation: appBarTheme.elevation ?? 1.0,
        iconTheme: appBarTheme.iconTheme ?? const IconThemeData(color: Color(0xFF00695C)),
        leading: IconButton( // Add a back button
            icon: Icon(Icons.arrow_back, color: appBarTheme.iconTheme?.color ?? const Color(0xFF00695C)),
            onPressed: () => Navigator.of(context).pop(),
          ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications') // The collection name you decided on
            .where('userId', isEqualTo: _currentUserId) // Filter by current user's ID
            .orderBy('createdAt', descending: true) // Show newest first
            .limit(50) // Optional: Limit the number of notifications displayed
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))));
          }
          if (snapshot.hasError) {
            print("Error fetching notifications: ${snapshot.error}");
            return Center(child: Text("Error loading notifications. Please try again.", style: GoogleFonts.poppins()));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("You have no notifications yet.", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16)));
          }

          final notifications = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => Divider(height: 1, indent: 72, endIndent: 16, color: Colors.grey.shade200), // Indent divider
            itemBuilder: (context, index) {
              final notificationDoc = notifications[index];
              final notificationData = notificationDoc.data() as Map<String, dynamic>;

              final String title = notificationData['title'] ?? 'Notification';
              final String body = notificationData['body'] ?? 'No content available.';
              final Timestamp? createdAt = notificationData['createdAt'] as Timestamp?;
              final bool isRead = notificationData['isRead'] ?? false;
              // Use the notificationId stored in the document, or fallback to Firestore doc ID
              final String notificationId = notificationData['notificationId'] ?? notificationDoc.id;

              String formattedTime = "Just now";
              if (createdAt != null) {
                try {
                  final now = DateTime.now();
                  final date = createdAt.toDate();
                  final difference = now.difference(date);

                  if (difference.inSeconds < 60) {
                    formattedTime = "${difference.inSeconds}s ago";
                  } else if (difference.inMinutes < 60) {
                    formattedTime = "${difference.inMinutes}m ago";
                  } else if (difference.inHours < 24) {
                    formattedTime = "${difference.inHours}h ago";
                  } else if (difference.inDays == 1 && now.day - date.day == 1) {
                     formattedTime = "Yesterday, ${DateFormat('hh:mm a').format(date)}";
                  } else {
                    formattedTime = DateFormat('MMM d, yy hh:mm a').format(date); // Include year for older
                  }
                } catch (e) {
                  print("Error formatting date for notification: $e");
                  formattedTime = "Date unavailable";
                }
              }

              return ListTile(
                leading: CircleAvatar( // Using CircleAvatar for icon background
                  radius: 24,
                  backgroundColor: isRead ? Colors.grey.shade300 : Theme.of(context).primaryColor.withOpacity(0.15),
                  child: Icon(
                    isRead ? Icons.mark_email_read_outlined : Icons.mark_email_unread_rounded,
                    color: isRead ? Colors.grey.shade600 : Theme.of(context).primaryColor,
                    size: 26,
                  ),
                ),
                title: Text(
                    title,
                    style: GoogleFonts.poppins(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                        color: isRead ? Colors.grey.shade700 : Colors.black87,
                        fontSize: 15.0 // Adjusted font size
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(color: isRead ? Colors.grey.shade600 : Colors.black54, fontSize: 13.0), // Adjusted font size
                    ),
                    const SizedBox(height: 5),
                    Text(
                        formattedTime,
                        style: GoogleFonts.poppins(fontSize: 11.0, color: Colors.grey.shade500), // Adjusted font size
                    ),
                  ],
                ),
                tileColor: Colors.white, // Ensure consistent tile color
                contentPadding: const EdgeInsets.only(left:16, right: 16, top: 10, bottom: 10),
                onTap: () async {
                  // Mark as read in Firestore
                  if (!isRead) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(notificationId)
                          .update({'isRead': true});
                    } catch (e) {
                       print("Error marking notification as read: $e");
                       if(mounted){
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text("Could not mark notification as read.", style: GoogleFonts.poppins()))
                         );
                       }
                    }
                  }

                  // This is where the tap action is handled for navigation
                  final Map<String, dynamic>? fcmTapData = notificationData['data'] as Map<String, dynamic>?;

                  if (fcmTapData != null && fcmTapData.containsKey('screen')) {
                     _handleNotificationTap(context, fcmTapData);
                  } else if (notificationData['relatedDocId'] != null && notificationData['relatedCollection'] != null) {
                    // Fallback if 'data' map (original FCM data) is not populated in Firestore,
                    // but relatedDocId/Collection exists.
                    String screenPath = '/${notificationData['relatedCollection']}'; // e.g., /appointments
                    // You might need more sophisticated mapping if collection names don't directly map to routes.
                     _handleNotificationTap(context, {
                      'screen': screenPath,
                      'id': notificationData['relatedDocId']
                    });
                  } else {
                    print("No specific navigation data found in this notification to act upon tap.");
                    // Optionally, you could navigate to a generic notification detail view
                    // or simply do nothing further if no actionable data is present.
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
