// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'admin_data_seeder_screen.dart'; // Add this import
import 'login_screen.dart';
import 'select_category_screen.dart';
// ... (your helper icon widgets remain the same) ...
Widget _buildCompositeProfileIcon({
  required Color color,
  double shoulderWidth = 24,
  double shoulderHeight = 16,
  double headDiameter = 12,
  double headOffsetY = -4.0,
  double headOffsetX = 0.0,
}) {
  double calculatedHeight = shoulderHeight;
  if (headOffsetY + headDiameter > shoulderHeight) {
    calculatedHeight = headOffsetY + headDiameter;
  } else {
    calculatedHeight = shoulderHeight + (headOffsetY < 0 ? headOffsetY.abs() : 0);
    if (headOffsetY + headDiameter > calculatedHeight) {
        calculatedHeight = headOffsetY + headDiameter;
    }
  }
  if (calculatedHeight < headDiameter && headOffsetY < 0) {
    calculatedHeight = headDiameter + headOffsetY.abs();
  }
  if (calculatedHeight < (shoulderHeight + headDiameter / 2) && headOffsetY > -headDiameter/2) {
      calculatedHeight = shoulderHeight + headDiameter/2 + 2;
  }

  return SizedBox(
    width: shoulderWidth,
    height: calculatedHeight,
    child: Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: shoulderHeight,
          child: SvgPicture.asset(
            'assets/icons/profile_icon_1.svg', 
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            fit: BoxFit.fill,
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: Offset(headOffsetX, headOffsetY),
            child: SvgPicture.asset(
              'assets/icons/profile_icon_2.svg', 
              width: headDiameter,
              height: headDiameter,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    ),
  );
}
Widget _buildCompositeAppointmentIcon({
  required Color outerColor,
  required Color innerColor,
  double circleDiameter = 28,
  double innerIconSize = 16,
}) {
  return SizedBox(
    width: circleDiameter,
    height: circleDiameter,
    child: Stack(
      alignment: Alignment.center,
      children: <Widget>[
        SvgPicture.asset(
          'assets/icons/appointment_icon_2.svg', 
          width: circleDiameter,
          height: circleDiameter,
          colorFilter: ColorFilter.mode(outerColor, BlendMode.srcIn),
          fit: BoxFit.contain,
        ),
        SvgPicture.asset(
          'assets/icons/appointment_icon_1.svg', 
          width: innerIconSize,
          height: innerIconSize,
          colorFilter: ColorFilter.mode(innerColor, BlendMode.srcIn),
          fit: BoxFit.contain,
        ),
      ],
    ),
  );
}
Widget _buildRecordsIcon({required Color color, double size = 24}) {
  return SvgPicture.asset(
    'assets/icons/records_icon_1.svg', 
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  User? _currentUser;
  Map<String, dynamic>? _userData; 

  DocumentSnapshot? _latestPrescription;
  List<DocumentSnapshot> _upcomingAppointments = [];

  bool _isLoadingUserData = true; 
  bool _isLoadingPrescription = true;
  bool _isLoadingAppointments = true;
  
  String _appBarDisplayName = "Loading..."; 

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _appBarDisplayName = _currentUser!.displayName ?? _currentUser!.email ?? "User"; 
      _loadAllData();
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
     WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Ensure widget is still in the tree
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
        }
      });
  }

  Future<void> _loadAllData() async {
    if (!mounted || _currentUser == null) return; // Added check for _currentUser
    setState(() {
      _isLoadingUserData = true; 
      _isLoadingPrescription = true;
      _isLoadingAppointments = true;
    });

    await Future.wait([
      _fetchUserData(), 
      _fetchLatestPrescription(),
      _fetchUpcomingAppointments(),
    ]);

    if (!mounted) return;
    _updateAppBarDisplayName(); 
    
    if (mounted) {
        setState(() {});
    }
  }
  
  void _updateAppBarDisplayName() {
    if (_userData != null && _userData!['displayName'] != null && _userData!['displayName'].isNotEmpty) {
      _appBarDisplayName = _userData!['displayName'];
    } else if (_currentUser != null && _currentUser!.displayName != null && _currentUser!.displayName!.isNotEmpty) { // Check if displayName from auth is not empty
        _appBarDisplayName = _currentUser!.displayName!;
    } else if (_currentUser != null && _currentUser!.email != null) { // Fallback to email
         _appBarDisplayName = _currentUser!.email!;
    }
     else {
        _appBarDisplayName = "User"; 
    }
  }

  Future<void> _fetchUserData() async { 
    if (_currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
          _appBarDisplayName = "User"; 
        });
      }
      return;
    }

    try {
      DocumentSnapshot userDocSnap = await _firestore
          .collection('users') 
          .doc(_currentUser!.uid)
          .get();

      Map<String, dynamic>? fetchedData;
      if (userDocSnap.exists) {
        fetchedData = userDocSnap.data() as Map<String, dynamic>;
      }
      
      if (mounted) {
        setState(() {
          _userData = fetchedData; 
          _isLoadingUserData = false;
          // _updateAppBarDisplayName(); // Called in _loadAllData after all fetches
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
          // _updateAppBarDisplayName(); // Called in _loadAllData
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load user data.')),
        );
      }
    }
  }

  Future<void> _fetchLatestPrescription() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoadingPrescription = false);
      return;
    }
    if (mounted && !_isLoadingPrescription) setState(() => _isLoadingPrescription = true);

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('prescriptions')
          .where('userId', isEqualTo: _currentUser!.uid) 
          .orderBy('issueDate', descending: true) 
          .limit(1)
          .get();
      if (mounted) {
        setState(() {
          if (snapshot.docs.isNotEmpty) {
            _latestPrescription = snapshot.docs.first;
          } else {
            _latestPrescription = null; 
          }
          _isLoadingPrescription = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPrescription = false);
      debugPrint("Error fetching prescription: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load prescription: ${e.toString()}')),
      );
      }
    }
  }

  Future<void> _fetchUpcomingAppointments() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoadingAppointments = false);
      return;
    }
    if (mounted && !_isLoadingAppointments) setState(() => _isLoadingAppointments = true);
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: _currentUser!.uid)
          .where('dateTimeFull', isGreaterThanOrEqualTo: Timestamp.now()) 
          .orderBy('dateTimeFull', descending: false) 
          .limit(2) 
          .get();
      if (mounted) {
        setState(() {
          _upcomingAppointments = snapshot.docs;
          _isLoadingAppointments = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAppointments = false);
      debugPrint("Error fetching appointments: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load appointments: ${e.toString()}')),
      );
      }
    }
  }

  Future<void> _logoutUser() async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context, 
      builder: (BuildContext dialogContext) { 
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); 
              },
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); 
              },
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) { 
        try {
          // Correctly declare and use isGoogleUser
          bool isGoogleUser = _auth.currentUser?.providerData
              .any((userInfo) => userInfo.providerId == GoogleAuthProvider.PROVIDER_ID) ?? false;

          if (isGoogleUser) {
            await _googleSignIn.signOut();
            debugPrint("Google user signed out.");
          }
          
          await _auth.signOut();
          debugPrint("Firebase user signed out.");

          if (mounted) { 
            _navigateToLogin();
          }

        } catch (e) {
          if (mounted) { 
            ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging out: ${e.toString()}')),
            );
          }
          debugPrint("Logout error: $e");
        }
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) { 
      _scanQrCode();
      return; 
    }
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _scanQrCode() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Code Scanner Tapped! (Not Implemented)')),
      );
    }
  }

  void _addNewAppointmentAction() {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SelectCategoryScreen()),
      ).then((valueFromNextScreen) {
        if (valueFromNextScreen == true || valueFromNextScreen == null) { 
            _fetchUpcomingAppointments();
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    const Color selectedColor = Color(0xFF008080);
    const Color unselectedColor = Colors.grey;

    return Scaffold(
      body: RefreshIndicator( 
        onRefresh: _loadAllData, 
        color: selectedColor, 
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              expandedHeight: 100.0,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF6EB6B4),
              elevation: 2, 
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16.0, bottom: 16.0, right: 50.0), 
                title: Text(
                  'Hi, $_appBarDisplayName', // Corrected: Removed unnecessary braces
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22.0, 
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis, 
                ),
                background: Container( 
                    decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF6EB6B4), Color(0xFF4BA5A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                    ),
                    ),
                ),
              ),
              // In home_screen.dart, inside SliverAppBar -> actions:
actions: [
  IconButton( // Temporary button for seeding
    icon: const Icon(Icons.construction, color: Colors.yellow),
    tooltip: 'Seed Data (Admin)',
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AdminDataSeederScreen()),
      );
    },
  ),
  IconButton(
    icon: const Icon(Icons.logout, color: Colors.white),
    tooltip: 'Logout',
    onPressed: _logoutUser,
  ),
],
              
            ),
            (_isLoadingUserData && _userData == null) 
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)))
                    ),
                  )
                : SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        if (!_isLoadingUserData && _userData == null) 
                            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Could not load user details. Pull to refresh.", style: TextStyle(color: Colors.grey))))
                        else if (_userData != null) 
                            _buildUserInfoCard(_userData), 
                        
                        _buildActionButtonsGrid(),
                        _buildPrescriptionSection(),
                        _buildAppointmentsSection(),
                        const SizedBox(height: 20), 
                      ],
                    ),
                  ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/home_icon.svg', 
              width: 24, height: 24,
              colorFilter: ColorFilter.mode(_selectedIndex == 0 ? selectedColor : unselectedColor, BlendMode.srcIn),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _buildRecordsIcon(color: _selectedIndex == 1 ? selectedColor : unselectedColor),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: InkWell( 
              onTap: _scanQrCode, 
              customBorder: const CircleBorder(),
              child: Padding( 
                padding: const EdgeInsets.all(8.0),
                child: SvgPicture.asset(
                  'assets/icons/qr_code_scanner.svg', 
                  width: 28, height: 28,
                  colorFilter: const ColorFilter.mode(selectedColor, BlendMode.srcIn), 
                ),
              ),
            ),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/nearby.svg', 
              width: 24, height: 24,
              colorFilter: ColorFilter.mode(_selectedIndex == 3 ? selectedColor : unselectedColor, BlendMode.srcIn),
            ),
            label: 'Nearby',
          ),
          BottomNavigationBarItem(
            icon: _buildCompositeProfileIcon(color: _selectedIndex == 4 ? selectedColor : unselectedColor),
            label: 'Profile',
          ),
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
    );
  }

  Widget _buildUserInfoCard(Map<String, dynamic>? userData) { 
    if (userData == null) { 
      return const Card(
        margin: EdgeInsets.all(16.0),
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(child: Text("User information not available.")),
        ),
      );
    }
    
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
                backgroundImage: (profilePicUrl != null && profilePicUrl.isNotEmpty)
                    ? NetworkImage(profilePicUrl)
                    : null,
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
        style: TextStyle(fontSize: 15, color: Colors.grey[850]), 
        children: <TextSpan>[
          TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF00695C))), 
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
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 2.4, 
        children: <Widget>[
          _actionButton(
            iconPath: 'assets/icons/medical_icon.svg',
            label: 'Book Appointment', 
            onTap: _addNewAppointmentAction, 
          ),
          _actionButton(
            iconPath: 'assets/icons/labs_icon.svg',
            label: 'Book Lab Test',
            onTap: () {
              if(mounted) { 
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Book Lab Test (Not Implemented)')));
              }
              debugPrint('Book Lab Test Tapped');
            },
          ),
          _actionButton(
            iconPath: 'assets/icons/order_icon_1.svg',
            label: 'Order Medicine',
            onTap: () {
                if(mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order Medicine (Not Implemented)'))
                );
                }
              debugPrint('Order Medicine Tapped');
            },
          ),
          _actionButton(
            iconPath: 'assets/icons/video_icon.svg',
            label: 'Video Consultation',
            onTap: () {
                if(mounted) { 
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video Consultation (Not Implemented)'))
                );
                }
              debugPrint('Video Consultation Tapped');
            },
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
      {required String iconPath,
      required String label,
      required VoidCallback onTap}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF008080),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: Colors.grey[300]!, width: 1.0), 
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0), 
        elevation: 2.0, 
        shadowColor: Colors.grey.withAlpha(51), 
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SvgPicture.asset(iconPath, 
              width: 26, 
              height: 26,
              colorFilter:
                  const ColorFilter.mode(Color(0xFF008080), BlendMode.srcIn)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 13.5, 
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionSection() {
    if (_isLoadingPrescription && _latestPrescription == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)))));
    }
    
    String prescriptionDetails;
    if (_latestPrescription != null && _latestPrescription!.exists) {
      Map<String, dynamic> data = _latestPrescription!.data() as Map<String, dynamic>;
      String doctorName = data['doctorName'] ?? 'N/A';
      String dateIssuedFormatted = "N/A";
      if (data['issueDate'] is Timestamp) { 
        dateIssuedFormatted = DateFormat('dd MMM, yy').format((data['issueDate'] as Timestamp).toDate());
      }
      List<dynamic> medications = data['medications'] ?? [];
      if (medications.isNotEmpty) {
        String medsSummary = medications
            .take(2) 
            .map((med) => "- ${med['medicineName'] ?? 'N/A'} (${med['dosage'] ?? 'N/A'}) - ${med['frequency'] ?? 'N/A'}") 
            .join("\n");
        if (medications.length > 2) {
            medsSummary += "\n- ...and more";
        }
        prescriptionDetails = "Latest from Dr. $doctorName on $dateIssuedFormatted:\n$medsSummary";
      } else {
        prescriptionDetails = "Latest prescription from Dr. $doctorName on $dateIssuedFormatted has no listed medications.";
      }
    } else { 
        prescriptionDetails = "No prescriptions available at the moment.";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Card(
        elevation: 1.5,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: Colors.grey[300]!, width: 0.5)),
        color: Colors.white,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), 
          leading: SvgPicture.asset(
            'assets/icons/medical_icon.svg', 
            width: 28, height: 28, 
            colorFilter: const ColorFilter.mode(Color(0xFF008080), BlendMode.srcIn),
          ),
          title: const Text('Latest Prescription', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF00695C))),
          iconColor: const Color(0xFF008080),
          collapsedIconColor: Colors.grey[600],
          childrenPadding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0, top: 0), 
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 8.0), 
              child: Text(prescriptionDetails, style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.4)), 
            ), 
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('View All Prescriptions (Not Implemented)')),
                    );
                  }
                },
                child: const Text('View All', style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsSection() {
    if (_isLoadingAppointments && _upcomingAppointments.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20.0),child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)))));
    }
    
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0, top: 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Upcoming Appointments', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF00695C))),
              InkWell(
                onTap: _addNewAppointmentAction, 
                customBorder: const CircleBorder(),
                child: Tooltip(
                  message: 'Add New Appointment',
                  child: _buildCompositeAppointmentIcon(
                    outerColor: Colors.teal.shade300, innerColor: const Color(0xFF008080), circleDiameter: 38, innerIconSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _upcomingAppointments.isEmpty && !_isLoadingAppointments
              ? Card( 
                  elevation: 0,
                  color: Colors.grey[100],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                    child: Center(child: Text("No upcoming appointments. Tap '+' to book.", style: TextStyle(color: Colors.grey, fontSize: 15))),
                  ),
                )
              : Column(
                  children: _upcomingAppointments.map((doc) {
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    String name = data['doctorName'] ?? data['labTestName'] ?? data['category'] ?? 'Appointment'; 
                    String dateTimeStr = 'Date/Time N/A';
                    String status = data['status'] ?? 'N/A'; 

                    if (data['dateTimeFull'] != null && data['dateTimeFull'] is Timestamp) {
                      DateTime dt = (data['dateTimeFull'] as Timestamp).toDate();
                      dateTimeStr = DateFormat('EEE, dd MMM, yy  •  hh:mm a').format(dt); 
                    }

                    Widget profileIconWidget = _buildCompositeProfileIcon(
                        color: const Color(0xFF008080), shoulderWidth: 22, shoulderHeight: 11, headDiameter: 12, headOffsetY: -2.5);
                    
                    if (data['category'] == 'Lab Test' || data['labTestName'] != null) { 
                        profileIconWidget = CircleAvatar(
                        backgroundColor: Colors.teal.withAlpha(30),
                        child: SvgPicture.asset('assets/icons/labs_icon.svg', width: 22, height: 22, colorFilter: const ColorFilter.mode(Color(0xFF008080), BlendMode.srcIn)),
                        );
                    } else if (data['appointmentType'] == 'video') { 
                        profileIconWidget = CircleAvatar(
                        backgroundColor: Colors.teal.withAlpha(30),
                        child: SvgPicture.asset('assets/icons/video_icon.svg', width: 22, height: 22, colorFilter: const ColorFilter.mode(Color(0xFF008080), BlendMode.srcIn)),
                        );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: _buildAppointmentItem(
                        profileWidget: profileIconWidget,
                        name: name,
                        dateTime: dateTimeStr,
                        status: status, 
                        onTap: () {
                          if(mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Tapped on ${doc.id} (View Details - Not Implemented)')),
                            );
                          }
                        }
                      ),
                    );
                  }).toList(),
                ),
          if (!_isLoadingAppointments && _upcomingAppointments.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('View All Appointments (Not Implemented)')),
                    );
                  }
                },
                child: const Text('View All', style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppointmentItem({
    required Widget profileWidget,
    required String name,
    required String dateTime,
    required String status, 
    VoidCallback? onTap,
  }) {
      Color statusColor = Colors.grey; 
      String displayStatus = status.replaceAll('_', ' ').capitalizeFirstLetter();

      switch (status.toLowerCase()) {
          case 'booked': 
          statusColor = Colors.blue.shade600;
          break;
          case 'confirmed':
          statusColor = Colors.green.shade600;
          break;
          case 'completed':
          statusColor = Colors.teal.shade600;
          break;
          case 'cancelled': 
          statusColor = Colors.red.shade600;
          break;
      }

      return Card(
      elevation: 1.5, 
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(color: Colors.grey[200]!, width: 0.8)),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0), 
        leading: CircleAvatar( 
            radius: 22,
            backgroundColor: Colors.transparent, 
            child: profileWidget,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: Color(0xFF004D40))), 
        subtitle: Column( 
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(dateTime, style: TextStyle(color: Colors.grey[700], fontSize: 13.5)), 
                const SizedBox(height: 3),
                Text(
                    displayStatus,
                    style: TextStyle(color: statusColor, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
            ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 15, color: Colors.grey[500]), 
        onTap: onTap ?? () {
            debugPrint('Appointment Tapped: $name');
          },
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
