// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// Your existing screen imports
import 'login_screen.dart';
import 'select_category_screen.dart';
import 'nearby_screen_gplaces.dart';
import 'profile_screen.dart';
import 'records_list_screen.dart';
import 'book_lab_test_screen.dart';
import 'medical_voice_assistant.dart';

// Notification specific imports
import '../notification_service.dart';
// import '../notification_center_screen.dart'; // Navigated by route name

// Your existing helper icon widgets (ensure asset paths are correct)
Widget _buildCompositeProfileIcon({
  required Color color,
  double shoulderWidth = 24,
  double shoulderHeight = 16,
  double headDiameter = 12,
  double headOffsetY = -4.0,
  double headOffsetX = 0.0,
}) {
  return Icon(Icons.person_outline_rounded, color: color, size: 24);
}

Widget _buildCompositeAppointmentIcon({
  required Color outerColor,
  required Color innerColor,
  double circleDiameter = 28,
  double innerIconSize = 16,
}) {
  return Icon(Icons.calendar_today_outlined, color: outerColor, size: circleDiameter);
}

Widget _buildRecordsIcon({required Color color, double size = 24}) {
  return Icon(Icons.folder_shared_outlined, color: color, size: size);
}


class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _userData;
  DocumentSnapshot? _latestPrescription;
  List<DocumentSnapshot> _upcomingAppointments = [];
  bool _isHomeDataLoading = true;
  String _appBarDisplayName = "Loading...";

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _recordsNavigatorKey = GlobalKey<NavigatorState>();

  late final List<Widget> _widgetOptions;

  String _fcmTokenStatus = "Initializing FCM...";
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = widget.user.uid;
    _initializeFCMSetup();

    _widgetOptions = <Widget>[
      Navigator(
        key: _homeNavigatorKey,
        onGenerateRoute: (routeSettings) {
          return MaterialPageRoute(builder: (context) => _buildHomeTabBody());
        },
      ),
      Navigator( // Records Tab
        key: _recordsNavigatorKey,
        onGenerateRoute: (routeSettings) {
          return MaterialPageRoute(builder: (context) => const RecordsListScreen());
        },
      ),
      const MedicalVoiceAssistant(),
      const NearbyScreenWithGooglePlaces(key: ValueKey("nearby_screen")),
      const ProfileScreen(key: ValueKey("profile_screen")),
    ];

    _appBarDisplayName = widget.user.displayName?.isNotEmpty == true
        ? widget.user.displayName!
        : (widget.user.email ?? "User");
    
    Future.microtask(() => _loadHomeData());
  }

  Future<void> _initializeFCMSetup() async {
    if (_userId.isEmpty) {
      print("HomeScreen: User ID is empty. FCM setup cannot proceed.");
      if (mounted) setState(() => _fcmTokenStatus = "User ID not available for FCM.");
      return;
    }
    print("HomeScreen: Initializing FCM for user $_userId");
    await _requestNotificationPermissions();
    await _storeAndListenFCMToken();
    _setupFCMListeners();
  }

  Future<void> _requestNotificationPermissions() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true, announcement: false, badge: true, carPlay: false,
      criticalAlert: false, provisional: false, sound: true,
    );
    print('HomeScreen: User granted notification permission status: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.denied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification permissions denied. You might miss important updates.')),
      );
    }
  }

  Future<void> _storeAndListenFCMToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (mounted) setState(() => _fcmTokenStatus = token ?? "Failed to get FCM token");
      print("HomeScreen: FCM Token for user $_userId: $token");

      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(_userId).set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print("HomeScreen: FCM token stored/updated for user $_userId");
      }
    } catch (e) {
      print("HomeScreen: Error getting or storing FCM token: $e");
      if (mounted) setState(() => _fcmTokenStatus = "Error storing token: $e");
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print("HomeScreen: FCM Token Refreshed: $newToken for user $_userId");
      if (_userId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(_userId).set({
            'fcmTokens': FieldValue.arrayUnion([newToken])
          }, SetOptions(merge: true));
          print("HomeScreen: Refreshed FCM token stored for user $_userId");
        } catch (e) {
          print("HomeScreen: Error storing refreshed FCM token: $e");
        }
      }
    });
  }

  void _setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('HomeScreen: Foreground message received!');
      if (message.notification != null) print('Message title: ${message.notification?.title}, body: ${message.notification?.body}');
      print('Message data: ${message.data}');
      NotificationService().showNotification(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print("HomeScreen: App opened from terminated state by tapping notification. Type: ${message.data['type']}");
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _handleNotificationTap(message.data);
        });
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('HomeScreen: App opened from background by tapping notification. Type: ${message.data['type']}');
       if (mounted) _handleNotificationTap(message.data);
    });
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    print("HomeScreen: Handling notification tap with data: $data");
    final String? screen = data['screen']?.toString();
    final String? id = data['id']?.toString();

    if (screen != null && screen.isNotEmpty) {
      if (mounted) {
         Navigator.of(context, rootNavigator: true).pushNamed(screen, arguments: id);
         print("HomeScreen: Navigating to screen: $screen with ID: $id");
      }
    } else {
      print("HomeScreen: No screen specified in notification data for navigation.");
    }
  }

  Future<void> _loadHomeData() async {
    if (!mounted) return;
    // Ensure _isHomeDataLoading is true at the start of any load attempt,
    // but only set state if it's currently false to avoid unnecessary rebuilds if already loading.
    if (!_isHomeDataLoading) {
      setState(() => _isHomeDataLoading = true);
    }

    try {
      // Fetch user data
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_userId).get()
          .catchError((e) {
            print("Error fetching user document: $e");
            throw e; // Re-throw to be caught by the outer try-catch
          });
      Map<String, dynamic>? fetchedUserData = userDoc.exists ? userDoc.data() as Map<String, dynamic> : null;

      // Fetch prescriptions and appointments concurrently
      final results = await Future.wait([
        _fetchLatestPrescriptionInternal(_userId).catchError((e) {
          print("Error in _fetchLatestPrescriptionInternal during Future.wait: $e");
          return null; // Return null on error to allow Future.wait to complete
        }),
        _fetchUpcomingAppointmentsInternal(_userId).catchError((e) {
          print("Error in _fetchUpcomingAppointmentsInternal during Future.wait: $e");
          return <DocumentSnapshot>[]; // Return empty list on error
        }),
      ]);

      final DocumentSnapshot? fetchedPrescription = results[0] as DocumentSnapshot?;
      final List<DocumentSnapshot> fetchedAppointments = results[1] as List<DocumentSnapshot>;

      if (mounted) {
        setState(() {
          _userData = fetchedUserData;
          _appBarDisplayName = _determineAppBarName(widget.user, _userData);
          _latestPrescription = fetchedPrescription;
          _upcomingAppointments = fetchedAppointments;
          // _isHomeDataLoading = false; // Moved to finally block
        });
      }
    } catch (e) {
      debugPrint("Error loading home data in _loadHomeData's main try-catch: ${e.toString()}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading some home data. Please try again.', style: GoogleFonts.poppins())),
        );
        // Set to default/empty states but ensure loading is false
        setState(() {
          _userData = null;
          _appBarDisplayName = widget.user.email ?? "User"; // Fallback display name
          _latestPrescription = null;
          _upcomingAppointments = [];
          // _isHomeDataLoading = false; // Moved to finally block
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isHomeDataLoading = false; // CRITICAL: Always set loading to false in finally
        });
      }
    }
  }

  String _determineAppBarName(User user, Map<String, dynamic>? userData) {
    if (userData != null && userData['displayName'] != null && userData['displayName'].isNotEmpty) {
      return userData['displayName'];
    } else if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    } else if (user.email != null) {
      return user.email!;
    }
    return "User";
  }

  Future<DocumentSnapshot?> _fetchLatestPrescriptionInternal(String userId) async {
    // Removed try-catch here as it's handled by .catchError in _loadHomeData
    QuerySnapshot snapshot = await _firestore.collection('prescriptions')
        .where('userId', isEqualTo: userId)
        .orderBy('issueDate', descending: true).limit(1).get();
    if (snapshot.docs.isNotEmpty) return snapshot.docs.first;
    return null;
  }

  Future<List<DocumentSnapshot>> _fetchUpcomingAppointmentsInternal(String userId) async {
    // Removed try-catch here as it's handled by .catchError in _loadHomeData
    QuerySnapshot snapshot = await _firestore.collection('appointments')
        .where('userId', isEqualTo: userId)
        .where('dateTimeFull', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('dateTimeFull', descending: false).limit(2).get();
    return snapshot.docs;
  }

  Future<void> _logoutUser() async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirm Logout', style: GoogleFonts.poppins()),
          content: Text('Are you sure you want to log out?', style: GoogleFonts.poppins()),
          actions: <Widget>[
            TextButton(child: Text('Cancel', style: GoogleFonts.poppins()), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(
                child: Text('Logout', style: GoogleFonts.poppins(color: Colors.red)),
                onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );
    if (confirmLogout == true) {
      try {
        bool isGoogleUser = _auth.currentUser?.providerData.any((userInfo) => userInfo.providerId == GoogleAuthProvider.PROVIDER_ID) ?? false;
        if (isGoogleUser) await _googleSignIn.signOut();
        await _auth.signOut();
        // Navigation to LoginScreen is handled by StreamBuilder in MyApp
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error logging out: ${e.toString()}', style: GoogleFonts.poppins())));
        debugPrint("Logout error: $e");
      }
    }
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    if (index == _selectedIndex) {
        switch (index) {
            case 0: if (_homeNavigatorKey.currentState?.canPop() == true) _homeNavigatorKey.currentState?.popUntil((route) => route.isFirst); break;
            case 1: if (_recordsNavigatorKey.currentState?.canPop() == true) _recordsNavigatorKey.currentState?.popUntil((route) => route.isFirst); break;
            // Add other cases for tabs with Navigators if necessary
        }
        return;
    }
    setState(() => _selectedIndex = index);
  }

  void _addNewAppointmentAction() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (context) => const SelectCategoryScreen()),
    ).then((valueFromNextScreen) {
      if (valueFromNextScreen == true || valueFromNextScreen == null) { // Assuming true indicates a change that needs refresh
        if (_selectedIndex == 0 && mounted) {
          _loadHomeData(); // Perform a full refresh of home data
        }
      }
    });
  }

  Widget _buildHomeTabBody() {
    final appBarTheme = Theme.of(context).appBarTheme;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        color: Theme.of(context).primaryColor,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              expandedHeight: 100.0,
              floating: false,
              pinned: true,
              backgroundColor: appBarTheme.backgroundColor ?? const Color(0xFF6EB6B4),
              elevation: appBarTheme.elevation ?? 2,
              iconTheme: appBarTheme.iconTheme,
              titleTextStyle: appBarTheme.titleTextStyle,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16.0, bottom: 16.0, right: 50.0),
                title: Text(
                  'Hi, $_appBarDisplayName',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 22.0, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF6EB6B4), Color(0xFF4BA5A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  tooltip: 'Notifications',
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pushNamed('/notification_center');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Logout',
                  onPressed: _logoutUser,
                ),
              ],
            ),
            _isHomeDataLoading
                ? const SliverFillRemaining(
                    key: ValueKey('homeLoaderSliver_loading'),
                    child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)))),
                  )
                : SliverList(
                    key: const ValueKey('homeContentSliver_content'),
                    delegate: SliverChildListDelegate(
                      [
                        if (_userData == null && !_isHomeDataLoading)
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Center(
                                child: Text("Could not load user details. Pull to refresh.",
                                    style: GoogleFonts.poppins(color: Colors.grey))),
                          )
                        else if (_userData != null)
                          _buildUserInfoCard(_userData),
                        _buildActionButtonsGrid(),
                        _buildPrescriptionSection(),
                        _buildAppointmentsSection(),
                        const SizedBox(height: 80), // Extra space for scrollability / FAB
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(Map<String, dynamic>? userData) {
    if (userData == null) return const SizedBox.shrink();
    String name = userData['displayName'] ?? 'N/A';
    String id = userData['patientId'] ?? 'N/A';
    String age = userData['age']?.toString() ?? 'N/A';
    String bloodGroup = userData['bloodGroup'] ?? 'N/A';
    String? profilePicUrl = userData['photoURL'];

    return Card(
      margin: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 20.0),
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      color: const Color(0xFFE0F2F1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoText('Name', name),
                  const SizedBox(height: 6),
                  _buildInfoText('Patient ID', id),
                  const SizedBox(height: 6),
                  _buildInfoText('Age', age),
                  const SizedBox(height: 6),
                  _buildInfoText('Blood Group', bloodGroup),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              flex: 1,
              child: CircleAvatar(
                radius: 35,
                backgroundColor: const Color(0xFF008080).withAlpha(100),
                backgroundImage: (profilePicUrl != null && profilePicUrl.isNotEmpty) ? NetworkImage(profilePicUrl) : null,
                child: (profilePicUrl == null || profilePicUrl.isEmpty)
                    ? const Icon(Icons.person_outline, size: 35, color: Color(0xFF00695C))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoText(String label, String value) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[850]),
        children: <TextSpan>[
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF00695C))),
          TextSpan(text: value, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w400)),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildActionButtonsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 15.0,
        crossAxisSpacing: 15.0,
        childAspectRatio: 1.25,
        children: [
          _actionButton(
            iconPath: 'assets/icons/medical_icon.svg',
            label: 'Book Doctor Appointment',
            onTap: _addNewAppointmentAction,
          ),
          _actionButton(
            iconPath: 'assets/icons/labs_icon.svg',
            label: 'Book Lab Test',
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (context) => const BookLabTestScreen()),
              );
            },
          ),
          _actionButton(
            iconPath: 'assets/icons/order_icon_1.svg',
            label: 'Order Medicine',
            onTap: () {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Medicine (Not Implemented)')));
            },
          ),
          _actionButton(
            iconPath: 'assets/icons/video_icon.svg',
            label: 'Video Consultation',
            onTap: () {
               Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (context) => const SelectCategoryScreen(bookingType: "video")),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required String iconPath, required String label, required VoidCallback onTap}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF008080),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), side: BorderSide(color: Colors.grey[300]!, width: 1.0)),
        padding: const EdgeInsets.all(10.0),
        elevation: 2.0,
        shadowColor: Colors.grey.withAlpha(51),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(iconPath, width: 32, height: 32, colorFilter: const ColorFilter.mode(Color(0xFF008080), BlendMode.srcIn)),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w500, height: 1.1),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionSection() {
    if (_latestPrescription == null && !_isHomeDataLoading) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Card(
            elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), color: Colors.white,
            child: Padding(padding: const EdgeInsets.all(16.0), child: Text("No prescriptions available.", style: GoogleFonts.poppins(color: Colors.grey))),
          )
      );
    }
    if (_latestPrescription == null) return const SizedBox.shrink();

    String prescriptionDetails;
    if (_latestPrescription!.exists) {
      Map<String, dynamic> data = _latestPrescription!.data() as Map<String, dynamic>;
      String doctorName = data['doctorName'] ?? 'N/A';
      String dateIssuedFormatted = (data['issueDate'] is Timestamp) ? DateFormat('dd MMM, yy').format((data['issueDate'] as Timestamp).toDate()) : "N/A";
      List<dynamic> medications = data['medications'] ?? [];
      prescriptionDetails = medications.isNotEmpty
          ? "Latest from Dr. $doctorName on $dateIssuedFormatted:\n${medications.take(2).map((med) => "- ${med['medicineName'] ?? 'N/A'} (${med['dosage'] ?? 'N/A'}) - ${med['frequency'] ?? 'N/A'}").join("\n")}${medications.length > 2 ? "\n- ...and more" : ""}"
          : "Latest from Dr. $doctorName on $dateIssuedFormatted has no listed medications.";
    } else {
      prescriptionDetails = "No prescriptions available at the moment.";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Card(
        elevation: 1.5,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), side: BorderSide(color: Colors.grey[300]!, width: 0.5)),
        color: Colors.white,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          leading: SvgPicture.asset('assets/icons/medical_icon.svg', width: 28, height: 28, colorFilter: const ColorFilter.mode(Color(0xFF008080), BlendMode.srcIn)),
          title: Text('Latest Prescription', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: const Color(0xFF00695C))),
          iconColor: const Color(0xFF008080),
          collapsedIconColor: Colors.grey[600],
          childrenPadding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0, top: 0),
          children: <Widget>[
            Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(prescriptionDetails, style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 14, height: 1.4))),
            const SizedBox(height: 10),
            Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () { /* TODO: Navigate to all prescriptions screen */ },
                    child: Text('View All', style: GoogleFonts.poppins(color: const Color(0xFF008080), fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsSection() {
    if (_upcomingAppointments.isEmpty && !_isHomeDataLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Upcoming Appointments', style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.bold, color: const Color(0xFF00695C))),
              InkWell(onTap: _addNewAppointmentAction, customBorder: const CircleBorder(), child: Tooltip(message: 'Add New Appointment', child: _buildCompositeAppointmentIcon(outerColor: Colors.teal.shade300, innerColor: const Color(0xFF008080), circleDiameter: 38, innerIconSize: 18))),
            ]),
            const SizedBox(height: 12),
            Card(elevation: 0, color: Colors.grey[100], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0), child: Text("No upcoming appointments. Tap '+' to book.", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 15))),
            ),
          ],
        ),
      );
    }
    if (_upcomingAppointments.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0, top: 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Upcoming Appointments', style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.bold, color: const Color(0xFF00695C))),
            InkWell(onTap: _addNewAppointmentAction, customBorder: const CircleBorder(), child: Tooltip(message: 'Add New Appointment', child: _buildCompositeAppointmentIcon(outerColor: Colors.teal.shade300, innerColor: const Color(0xFF008080), circleDiameter: 38, innerIconSize: 18))),
          ]),
          const SizedBox(height: 12),
          Column(
            children: _upcomingAppointments.map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              String name = data['doctorName'] ?? data['labTestName'] ?? data['category'] ?? 'Appointment';
              String dateTimeStr = (data['dateTimeFull'] is Timestamp) ? DateFormat('EEE, dd MMM, yy  •  hh:mm a').format((data['dateTimeFull'] as Timestamp).toDate()) : 'Date/Time N/A';
              String status = data['status'] ?? 'N/A';
              Widget profileIconWidget = _buildCompositeProfileIcon(color: const Color(0xFF008080), shoulderWidth: 22, shoulderHeight: 11, headDiameter: 12, headOffsetY: -2.5);
              if (data['category'] == 'Lab Test' || data['labTestName'] != null) {
                profileIconWidget = CircleAvatar(backgroundColor: Colors.teal.withAlpha(30), child: SvgPicture.asset('assets/icons/labs_icon.svg', width: 22, height: 22, colorFilter: const ColorFilter.mode(Color(0xFF008080), BlendMode.srcIn)));
              } else if (data['appointmentType'] == 'video') {
                 profileIconWidget = CircleAvatar(backgroundColor: Colors.teal.withAlpha(30), child: SvgPicture.asset('assets/icons/video_icon.svg', width: 22, height: 22, colorFilter: const ColorFilter.mode(Color(0xFF008080), BlendMode.srcIn)));
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: _buildAppointmentItem(profileWidget: profileIconWidget, name: name, dateTime: dateTimeStr, status: status, onTap: () {
                  Navigator.of(context, rootNavigator: true).pushNamed('/appointmentDetail', arguments: doc.id);
                }),
              );
            }).toList(),
          ),
          if (_upcomingAppointments.isNotEmpty)
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () { /* TODO: Navigate to all appointments */ }, child: Text('View All', style: GoogleFonts.poppins(color: const Color(0xFF008080), fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildAppointmentItem({ required Widget profileWidget, required String name, required String dateTime, required String status, VoidCallback? onTap, }) {
    Color statusColor = Colors.grey;
    String displayStatus = status.replaceAll('_', ' ').capitalizeFirstLetter();
    switch (status.toLowerCase()) {
      case 'booked': statusColor = Colors.blue.shade600; break;
      case 'confirmed': statusColor = Colors.green.shade600; break;
      case 'completed': statusColor = Colors.teal.shade600; break;
      case 'cancelled': statusColor = Colors.red.shade600; break;
      case 'video_link_added': statusColor = Colors.purple.shade600; displayStatus = "Video Link Added"; break;
    }
    return Card(
      elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: BorderSide(color: Colors.grey[200]!, width: 0.8)), color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        leading: CircleAvatar(radius: 22, backgroundColor: Colors.transparent, child: profileWidget ),
        title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15.5, color: const Color(0xFF004D40))),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dateTime, style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 13.5)),
          const SizedBox(height: 3),
          Text(displayStatus, style: GoogleFonts.poppins(color: statusColor, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ]),
        trailing: Icon(Icons.arrow_forward_ios, size: 15, color: Colors.grey[500]),
        onTap: onTap ?? () { debugPrint('Appointment Tapped: $name'); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color selectedColor = Color(0xFF008080);
    const Color unselectedColor = Colors.grey;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final NavigatorState? currentNavigatorState;
        switch (_selectedIndex) {
          case 0: currentNavigatorState = _homeNavigatorKey.currentState; break;
          case 1: currentNavigatorState = _recordsNavigatorKey.currentState; break;
          default: currentNavigatorState = null;
        }
        if (currentNavigatorState != null && currentNavigatorState.canPop()) {
          currentNavigatorState.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
        bottomNavigationBar: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: SvgPicture.asset('assets/icons/home_icon.svg', width: 24, height: 24, colorFilter: ColorFilter.mode(_selectedIndex == 0 ? selectedColor : unselectedColor, BlendMode.srcIn)), label: 'Home'),
            BottomNavigationBarItem(icon: _buildRecordsIcon(color: _selectedIndex == 1 ? selectedColor : unselectedColor), label: 'Records'),
            BottomNavigationBarItem(icon: SvgPicture.asset('assets/icons/medicall_icon.svg', width: 28, height: 28, colorFilter: ColorFilter.mode(_selectedIndex == 2 ? selectedColor : unselectedColor, BlendMode.srcIn)), label: 'Assistant'),
            BottomNavigationBarItem(icon: SvgPicture.asset('assets/icons/nearby.svg', width: 24, height: 24, colorFilter: ColorFilter.mode(_selectedIndex == 3 ? selectedColor : unselectedColor, BlendMode.srcIn)), label: 'Nearby'),
            BottomNavigationBarItem(icon: _buildCompositeProfileIcon(color: _selectedIndex == 4 ? selectedColor : unselectedColor), label: 'Profile'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: selectedColor,
          unselectedItemColor: unselectedColor,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          backgroundColor: Colors.white,
          elevation: 8.0,
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalizeFirstLetter() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
