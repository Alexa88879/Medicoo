// lib/notification_service.dart
import 'dart:convert'; // For jsonDecode if payload is a stringified map
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// If you decide to use a global navigator key for navigation from service (use with caution):
// import 'main.dart'; // Or wherever your GlobalKey<NavigatorState> navigatorKey is defined

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Optional: Define a global navigator key if you need to navigate from here.
  // This is generally less preferred than handling navigation in your UI layer (e.g., HomeScreen).
  // static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> init() async {
    // Android Initialization Settings
    // Ensure you have an icon named '@mipmap/ic_launcher' or replace it with your specific notification icon.
    // This icon is used by flutter_local_notifications.
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_notification'); // Use your specific notification icon if different from launcher

    // iOS Initialization Settings
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true, // Request permission to display alerts
      requestBadgePermission: true, // Request permission to update app badge
      requestSoundPermission: true, // Request permission to play sound
      // Remove the onDidReceiveLocalNotification parameter as it's no longer supported
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // Callback for when a user taps a local notification (app is in foreground or background)
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      // Callback for when a user taps a local notification and app was in background (not terminated)
      // This needs to be a static or top-level function.
      onDidReceiveBackgroundNotificationResponse: _onDidReceiveBackgroundNotificationResponse,
    );

    // Create Android Notification Channel (essential for Android 8.0+)
    await _createAndroidNotificationChannel();
  }

  Future<void> _createAndroidNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'curelink_high_importance_channel', // Channel ID (must match AndroidManifest.xml if set there for FCM)
      'CureLink Notifications', // Channel Name (user-visible in settings)
      description: 'This channel is used for important CureLink notifications.', // Channel Description (user-visible)
      importance: Importance.max, // Set importance to high for heads-up notifications
      playSound: true,
      // sound: RawResourceAndroidNotificationSound('notification_sound'), // Optional: if you have custom sound in android/app/src/main/res/raw
      // enableVibration: true, // Optional
      // showBadge: true, // Optional
    );

    // Register the channel with the OS
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Callback for older iOS versions when a local notification is received while the app is in the foreground.
  Future<void> _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    print("iOS foreground (onDidReceiveLocalNotification - local_notifications plugin): $id, Title: $title, Body: $body, Payload: $payload");
    // This is for local notifications shown by this plugin.
    // FCM foreground messages on iOS are typically handled by `FirebaseMessaging.onMessage` first.
    if (payload != null && payload.isNotEmpty) {
      try {
        Map<String, dynamic> data = jsonDecode(payload);
        print("Decoded payload for iOS foreground local notification: $data");
        // It's generally better to handle navigation from the main UI part (e.g., HomeScreen's _handleNotificationTap)
        // rather than directly from here to keep navigation logic centralized.
      } catch (e) {
        print("Error decoding payload for iOS foreground (onDidReceiveLocalNotification): $e");
      }
    }
  }

  // Called when a user taps a local notification (created by this service)
  // This is for notifications displayed by flutter_local_notifications.
  Future<void> _onDidReceiveNotificationResponse(NotificationResponse response) async {
    final String? payload = response.payload; // This is the stringified FCM data map
    print('Local notification tapped (onDidReceiveNotificationResponse), payload: $payload');
    if (payload != null && payload.isNotEmpty) {
      try {
        Map<String, dynamic> data = jsonDecode(payload);
        // IMPORTANT: Actual navigation logic should be centralized.
        // This callback signifies a tap on a *local* notification.
        // The `FirebaseMessaging.onMessageOpenedApp` and `getInitialMessage` in `home_screen.dart`
        // are the primary handlers for taps on *FCM-originated* notifications that open the app.
        // If this local notification was shown due to a foreground FCM message,
        // tapping it here could potentially trigger navigation.
        // However, ensure this doesn't conflict with the main FCM tap handlers.
        // A common pattern is to use a global stream/event bus to signal a tap
        // with its data, which the active UI can then listen to.
        print("Decoded data from local notification tap (onDidReceiveNotificationResponse): $data. Navigation should be handled in UI (e.g., HomeScreen).");
        // Example if using a global navigator key (use with caution):
        // if (NotificationService.navigatorKey.currentState != null && data.containsKey('screen')) {
        //   final String? screen = data['screen']?.toString();
        //   final String? id = data['id']?.toString();
        //   if (screen != null) {
        //     NotificationService.navigatorKey.currentState!.pushNamed(screen, arguments: id);
        //   }
        // }
      } catch (e) {
        print("Error decoding payload from local notification response (onDidReceiveNotificationResponse): $e");
      }
    }
  }

  // Needs to be a top-level function or static method for background isolate compatibility.
  // Called when a user taps a local notification and the app was in the background (not terminated).
  @pragma('vm:entry-point')
  static Future<void> _onDidReceiveBackgroundNotificationResponse(NotificationResponse response) async {
    final String? payload = response.payload;
    print('Local background notification tapped (_onDidReceiveBackgroundNotificationResponse), payload: $payload');
    if (payload != null && payload.isNotEmpty) {
      try {
        // Map<String, dynamic> data = jsonDecode(payload); // This part is fine
        // CRITICAL: You CANNOT perform UI navigation directly from this background isolate.
        // The app's UI is not running in this isolate.
        // Best practice:
        // 1. Save the `payload` (which contains your navigation data) to SharedPreferences or a background queue.
        // 2. When the app is next opened (or if it's already running in the main isolate),
        //    check this saved data in `initState` of your main screen (e.g., HomeScreen)
        //    and perform the navigation.
        // `FirebaseMessaging.onMessageOpenedApp` in `home_screen.dart` is the more direct way
        // to handle taps on FCM notifications that bring the app from background to foreground.
        print("Decoded data from local background notification tap (_onDidReceiveBackgroundNotificationResponse): $payload. Robust handling (e.g., saving intent) needed for background taps.");
      } catch (e) {
        print("Error decoding payload from local background notification response (_onDidReceiveBackgroundNotificationResponse): $e");
      }
    }
  }

  /// Displays a local notification, typically for foreground FCM messages.
  Future<void> showNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification; // FCM's standard visual part
    Map<String, dynamic> fcmData = message.data; // FCM's custom data payload

    // Use title/body from FCM data payload if available (for more control), fallback to notification part
    String title = fcmData['title'] ?? notification?.title ?? 'New CureLink Notification';
    String body = fcmData['body'] ?? notification?.body ?? 'You have a new message from CureLink.';

    // Android specific details using the high-importance channel
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        const AndroidNotificationDetails(
      'curelink_high_importance_channel', // Channel ID - MUST MATCH THE CREATED CHANNEL ID
      'CureLink Notifications',           // Channel Name
      channelDescription: 'This channel is used for important CureLink notifications.', // Channel Description
      importance: Importance.max,       // For heads-up notification
      priority: Priority.high,          // For heads-up notification
      showWhen: true,                   // Shows the time of the notification
      // styleInformation: BigTextStyleInformation(body), // Optional: for longer text that can be expanded
      // sound: RawResourceAndroidNotificationSound('notification_sound'), // Optional: custom sound
      // icon: '@mipmap/ic_notification', // Optional: if you want a specific icon for local notifications different from default
    );

    // iOS specific details
    DarwinNotificationDetails iOSPlatformChannelSpecifics =
        const DarwinNotificationDetails(
      presentAlert: true, // Ensure alert is shown for foreground messages on iOS
      presentBadge: true, // Controls if the app badge is updated by this local notification
      presentSound: true,
      // sound: 'custom_sound.aiff', // Optional: if you have custom sound in Runner/Sounds
    );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Generate a unique ID for the local notification.
    // Using message.messageId if available and non-empty, otherwise a timestamp.
    int notificationId = (message.messageId?.isNotEmpty == true
            ? message.messageId.hashCode // Using hashCode of string
            : DateTime.now().millisecondsSinceEpoch) %
        2147483647; // Ensure it fits in a 32-bit signed integer for Android

    // Pass the FCM data payload (which contains your navigation data like 'screen', 'id', 'type')
    // as the payload for the local notification. It needs to be a string.
    String localNotificationPayload = jsonEncode(fcmData);

    print("Showing local notification: ID=$notificationId, Title='$title', Body='$body', Payload='$localNotificationPayload'");

    await _flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: localNotificationPayload, // This payload is received in onDidReceiveNotificationResponse
    );
  }
}
