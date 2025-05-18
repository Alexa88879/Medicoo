import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import 'login_screen.dart'; // For navigation after logout
import 'book_appointment_screen.dart'; // For navigating to book appointment

// Import placeholder screens (create these files if you haven't, or remove if not needed yet)
// import 'qr_scanner_screen.dart';
// import 'all_appointments_screen.dart';
// import 'all_prescriptions_screen.dart';
// import 'profile_screen.dart';
// import 'records_screen.dart';
// import 'nearby_screen.dart';

// Helper widget for the composite profile icon
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

// Helper widget for the composite Appointment icon
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

// Reverted Records icon to simple version
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

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _fetchUserData();
      _fetchLatestPrescription();
      _fetchUpcomingAppointments();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
        }
      });
      if (mounted) {
         setState(() {
            _isLoadingUserData = false;
            _isLoadingPrescription = false;
            _isLoadingAppointments = false;
         });
      }
    }
  }

  Future<void> _fetchUserData() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoadingUserData = false);
      return;
    }
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      if (mounted) {
        setState(() {
          if (userDoc.exists) {
            _userData = userDoc.data() as Map<String, dynamic>?;
          }
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load user data.')),
        );
      }
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> _fetchLatestPrescription() async {
    if (_currentUser == null) {
       if (mounted) setState(() => _isLoadingPrescription = false);
      return;
    }
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('prescriptions')
          .where('patientUid', isEqualTo: _currentUser!.uid)
          .orderBy('dateIssued', descending: true)
          .limit(1)
          .get();
      if (mounted) {
        setState(() {
          if (snapshot.docs.isNotEmpty) {
            _latestPrescription = snapshot.docs.first;
          }
          _isLoadingPrescription = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPrescription = false;
        });
      }
      debugPrint("Error fetching prescription: $e");
    }
  }

  Future<void> _fetchUpcomingAppointments() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoadingAppointments = false);
      return;
    }
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientUid', isEqualTo: _currentUser!.uid)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('dateTime', descending: false)
          .limit(2) // Show a couple on the home screen
          .get();
      if (mounted) {
        setState(() {
          _upcomingAppointments = snapshot.docs;
          _isLoadingAppointments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAppointments = false;
        });
      }
      debugPrint("Error fetching appointments: $e");
    }
  }

  Future<void> _logoutUser() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
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

  void _onItemTapped(int index) {
    if (index == 2) { // Index 2 is the QR scanner
      _scanQrCode();
      return; // Don't change selected index for scan button if it's a direct action
    }
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
    debugPrint('Tapped on item with index: $index');
    // TODO: Implement navigation based on index for other tabs like Records, Nearby, Profile
    // For example:
    // if (index == 1) {
    //   Navigator.push(context, MaterialPageRoute(builder: (context) => const RecordsScreen()));
    // } else if (index == 4) {
    //   Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userData: _userData)));
    // }
  }

  void _scanQrCode() {
    // TODO: Navigate to QrScannerScreen and handle result
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Code Scanner Tapped! (Not Implemented Yet)')),
      );
    }
    debugPrint('Bottom Nav QR Code Scanner Tapped!');
  }

  void _addNewAppointmentAction() {
    // TODO: Navigate to a dedicated AddAppointmentScreen if different from BookAppointmentScreen
    // For now, let's assume it also goes to BookAppointmentScreen or a similar flow
    if (mounted) {
       Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BookAppointmentScreen()),
      );
    }
    debugPrint('Add New Appointment Icon Tapped');
  }


  @override
  Widget build(BuildContext context) {
    String displayName = _isLoadingUserData
        ? "Loading..."
        : (_userData?['displayName'] ?? _userData?['fullName'] ?? "User");
    const Color selectedColor = Color(0xFF008080);
    const Color unselectedColor = Colors.grey;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 100.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF6EB6B4),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
              title: Text(
                'Hii $displayName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
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
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Logout',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('Confirm Logout'),
                        content: const Text('Are you sure you want to log out?'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                          ),
                          TextButton(
                            child: const Text('Logout', style: TextStyle(color: Colors.red)),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _logoutUser();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                _isLoadingUserData
                    ? const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)))))
                    : _buildPatientInfoCard(_userData),
                _buildActionButtonsGrid(),
                _buildPrescriptionSection(),
                _buildAppointmentsSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/home_icon.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                  _selectedIndex == 0 ? selectedColor : unselectedColor,
                  BlendMode.srcIn),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _buildRecordsIcon(
              color: _selectedIndex == 1 ? selectedColor : unselectedColor,
              size: 24,
            ),
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
                  width: 28,
                  height: 28,
                  colorFilter: const ColorFilter.mode(selectedColor, BlendMode.srcIn),
                ),
              ),
            ),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/nearby.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                  _selectedIndex == 3 ? selectedColor : unselectedColor,
                  BlendMode.srcIn),
            ),
            label: 'Nearby',
          ),
          BottomNavigationBarItem(
            icon: _buildCompositeProfileIcon(
              color: _selectedIndex == 4 ? selectedColor : unselectedColor,
              shoulderWidth: 26, shoulderHeight: 13, headDiameter: 15, headOffsetY: -3.5, headOffsetX: 0,
            ),
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

  Widget _buildPatientInfoCard(Map<String, dynamic>? patientData) {
    String name = patientData?['displayName'] ?? patientData?['fullName'] ?? 'N/A';
    String id = patientData?['patientId'] ?? 'N/A';
    String age = patientData?['age']?.toString() ?? 'N/A';
    String bloodGroup = patientData?['bloodGroup'] ?? 'N/A';
    String? profilePicUrl = patientData?['profilePictureUrl'];

    return Card(
      margin: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 20.0),
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      color: const Color(0xFFE0F2F1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoText('Name', name),
                  const SizedBox(height: 5),
                  _buildInfoText('Id', id),
                  const SizedBox(height: 5),
                  _buildInfoText('Age', age),
                  const SizedBox(height: 5),
                  _buildInfoText('Blood Group', bloodGroup),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: CircleAvatar(
                radius: 35,
                backgroundColor: const Color(0xFF008080).withAlpha(128),
                backgroundImage: (profilePicUrl != null && profilePicUrl.isNotEmpty)
                    ? NetworkImage(profilePicUrl)
                    : null,
                child: (profilePicUrl == null || profilePicUrl.isEmpty)
                    ? Icon(Icons.person, size: 40, color: Colors.grey[100])
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
        style: TextStyle(fontSize: 15, color: Colors.grey[800]),
        children: <TextSpan>[
          TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF00695C))),
          TextSpan(text: value, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
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
        childAspectRatio: 2.3,
        children: <Widget>[
          _actionButton(
            iconPath: 'assets/icons/medical_icon.svg',
            label: 'Book\nAppointment',
            onTap: () {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BookAppointmentScreen()),
                );
              }
            },
          ),
          _actionButton(
            iconPath: 'assets/icons/labs_icon.svg',
            label: 'Book\nLab test',
            onTap: () {
              // TODO: Navigate to BookLabTestScreen
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Book Lab Test (Not Implemented)')));
              }
              debugPrint('Book Lab Test Tapped');
            },
          ),
          _actionButton(
            iconPath: 'assets/icons/order_icon_1.svg',
            label: 'Order\nMedicine',
            onTap: () {
              // TODO: Navigate to OrderMedicineScreen
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order Medicine (Not Implemented)'))
                );
              }
              debugPrint('Order Medicine Tapped');
            },
          ),
          _actionButton(
            iconPath: 'assets/icons/video_icon.svg',
            label: 'Video\nConsultation',
            onTap: () {
              // TODO: Navigate to VideoConsultationScreen
              if (mounted) {
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
          side: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        elevation: 1.5,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SvgPicture.asset(iconPath,
              width: 28,
              height: 28,
              colorFilter:
                  const ColorFilter.mode(Color(0xFF008080), BlendMode.srcIn)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 13,
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
    String prescriptionDetails = "No prescriptions found.";
    String doctorName = "N/A";
    String dateIssuedFormatted = "N/A";

    if (_isLoadingPrescription) {
      prescriptionDetails = "Loading prescriptions...";
    } else if (_latestPrescription != null && _latestPrescription!.exists) {
      Map<String, dynamic> data = _latestPrescription!.data() as Map<String, dynamic>;
      doctorName = data['doctorName'] ?? 'N/A';
      if (data['dateIssued'] is Timestamp) {
        dateIssuedFormatted = DateFormat('dd MMM, yyyy').format((data['dateIssued'] as Timestamp).toDate());
      }
      List<dynamic> medications = data['medications'] ?? [];
      if (medications.isNotEmpty) {
        String medsSummary = medications
            .map((med) => "- ${med['name']} (${med['dosage'] ?? 'N/A'}) - ${med['frequency'] ?? 'N/A'}")
            .join("\n");
         prescriptionDetails = "Latest from Dr. $doctorName on $dateIssuedFormatted:\n$medsSummary";
      } else {
        prescriptionDetails = "Latest prescription from Dr. $doctorName on $dateIssuedFormatted has no listed medications.";
      }
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          leading: SvgPicture.asset(
            'assets/icons/medical_icon.svg',
            width: 26, height: 26,
            colorFilter: const ColorFilter.mode(Color(0xFF008080), BlendMode.srcIn),
          ),
          title: const Text('Prescription', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF00695C))),
          iconColor: const Color(0xFF008080),
          collapsedIconColor: Colors.grey[600],
          childrenPadding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0, top: 8.0),
          children: <Widget>[
            _isLoadingPrescription
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))))
              : Text(prescriptionDetails, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO: Navigate to AllPrescriptionsScreen
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
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0, top: 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Appointments', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF00695C))),
              InkWell(
                onTap: _addNewAppointmentAction, // This now navigates to BookAppointmentScreen
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
          _isLoadingAppointments
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))))
              : _upcomingAppointments.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: Text("No upcoming appointments.")))
                  : Column(
                      children: _upcomingAppointments.map((doc) {
                        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                        String name = data['doctorName'] ?? data['testName'] ?? data['appointmentType'] ?? 'Appointment';
                        String dateTimeStr = 'Date/Time N/A';
                        if (data['dateTime'] != null && data['dateTime'] is Timestamp) {
                          DateTime dt = (data['dateTime'] as Timestamp).toDate();
                          dateTimeStr = DateFormat('dd MMM, yyyy - hh:mm a').format(dt);
                        }

                        Widget profileIconWidget = _buildCompositeProfileIcon(
                            color: const Color(0xFF008080), shoulderWidth: 22, shoulderHeight: 11, headDiameter: 12, headOffsetY: -2.5);
                        if (data['appointmentType'] == 'lab_test' || (data['testName'] != null)) {
                           profileIconWidget = CircleAvatar(
                              backgroundColor: Colors.teal.withAlpha(30),
                              child: SvgPicture.asset('assets/icons/labs_icon.svg', width: 22, height: 22, colorFilter: const ColorFilter.mode(Color(0xFF008080), BlendMode.srcIn)),
                            );
                        } else if (data['appointmentType'] == 'video_consultation') {
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
                            onTap: () {
                              // TODO: Navigate to AppointmentDetailsScreen(appointmentId: doc.id)
                              if(mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Tapped on ${doc.id} (Not Implemented)')),
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
                  // TODO: Navigate to AllAppointmentsScreen
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
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 1.0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(color: Colors.grey[200]!, width: 0.5)),
      color: Colors.white,
      child: ListTile(
        leading: profileWidget,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Color(0xFF004D40))),
        subtitle: Text(dateTime, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
        onTap: onTap ?? () {
            debugPrint('Appointment Tapped: $name');
          },
      ),
    );
  }
}