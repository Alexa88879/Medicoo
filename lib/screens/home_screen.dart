import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    'assets/icons/records_icon_1.svg', // Assuming this is the single SVG for records
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

  void _onItemTapped(int index) {
    if (index != 2) { // Index 2 is the QR scanner
      setState(() {
        _selectedIndex = index;
      });
    }
    debugPrint('Tapped on item with index: $index'); // Using Flutter's built-in logging
  }

  void _scanQrCode() { // This is for the bottom nav QR scanner
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR Code Scanner Tapped!')),
    );
    debugPrint('Bottom Nav QR Code Scanner Tapped!');
  }

  void _addNewAppointmentAction() { // Action for the new appointment icon
     ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add New Appointment Tapped!')),
    );
    debugPrint('Add New Appointment Icon Tapped - Implement action');
  }


  @override
  Widget build(BuildContext context) {
    const String userName = "Alexa";
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
              title: const Text(
                'Hii $userName',
                style: TextStyle(
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
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                _buildPatientInfoCard(),
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
            icon: _buildRecordsIcon( // Reverted to simple records icon
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
          // --- CORRECTED "NEARBY" TAB TO USE SVG ---
          BottomNavigationBarItem(
            icon: SvgPicture.asset( 
              'assets/icons/nearby.svg', // <<<< ENSURE THIS PATH IS CORRECT AND SVG IS IN ASSETS
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode( 
                  _selectedIndex == 3 ? selectedColor : unselectedColor,
                  BlendMode.srcIn),
            ),
            label: 'Nearby', 
          ),
          // --- END CORRECTED TAB ---
          BottomNavigationBarItem(
            icon: _buildCompositeProfileIcon(
              color: _selectedIndex == 4 ? selectedColor : unselectedColor,
              shoulderWidth: 26,
              shoulderHeight: 13,
              headDiameter: 15,
              headOffsetY: -3.5,
              headOffsetX: 0,
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

  Widget _buildPatientInfoCard() {
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
                  _buildInfoText('Name', 'Patient Name'),
                  const SizedBox(height: 5),
                  _buildInfoText('Id', '12345'),
                  const SizedBox(height: 5),
                  _buildInfoText('Age', '54'),
                  const SizedBox(height: 5),
                  _buildInfoText('Blood Group', 'O+'),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF008080), width: 2.5),
                ),
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
              debugPrint('Book Appointment Tapped');
            },
          ),
          _actionButton(
            iconPath: 'assets/icons/labs_icon.svg',
            label: 'Book\nLab test',
            onTap: () {
              debugPrint('Book Lab Test Tapped');
            },
          ),
          _actionButton(
            iconPath: 'assets/icons/order_icon_1.svg',
            label: 'Order\nMedicine',
            onTap: () {
              debugPrint('Order Medicine Tapped');
            },
          ),
          _actionButton(
            iconPath: 'assets/icons/video_icon.svg',
            label: 'Video\nConsultation',
            onTap: () {
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
            width: 26,
            height: 26,
            colorFilter: const ColorFilter.mode(Color(0xFF008080), BlendMode.srcIn),
          ),
          title: const Text(
            'Prescription',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00695C)),
          ),
          iconColor: const Color(0xFF008080),
          collapsedIconColor: Colors.grey[600],
          childrenPadding:
              const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
          children: <Widget>[
            const Text(
                'Latest prescription details will be shown here. You can list medications, dosage, and notes.'),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // Navigate to full prescription view
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                      color: Color(0xFF008080), fontWeight: FontWeight.bold),
                ),
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
              const Text(
                'Appointments',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00695C)),
              ),
              InkWell(
                onTap: _addNewAppointmentAction,
                customBorder: const CircleBorder(),
                child: Tooltip(
                  message: 'Add New Appointment',
                  child: _buildCompositeAppointmentIcon(
                    outerColor: Colors.teal.shade300,
                    innerColor: const Color(0xFF008080),
                    circleDiameter: 38,
                    innerIconSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAppointmentItem(
            profileWidget: _buildCompositeProfileIcon(
              color: const Color(0xFF008080),
              shoulderWidth: 22,
              shoulderHeight: 11,
              headDiameter: 12,
              headOffsetY: -2.5,
              headOffsetX: 0,
            ),
            name: 'Dr. Emily Carter (Cardiologist)',
            dateTime: '20 May, 2025 - 10:00 AM',
          ),
          const SizedBox(height: 10),
          _buildAppointmentItem(
            profileWidget: CircleAvatar(
              backgroundColor: Colors.teal.withAlpha(26),
              child: SvgPicture.asset('assets/icons/labs_icon.svg', // This is correct for the appointment item
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                      Color(0xFF008080), BlendMode.srcIn)),
            ),
            name: 'Lab Test: Blood Panel',
            dateTime: '21 May, 2025 - 08:30 AM',
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // Navigate to all appointments screen
              },
              child: const Text(
                'View All',
                style: TextStyle(
                    color: Color(0xFF008080), fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentItem(
      {required Widget profileWidget,
      required String name,
      required String dateTime}) {
    return Card(
      elevation: 1.0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(color: Colors.grey[200]!, width: 0.5)),
      color: Colors.white,
      child: ListTile(
        leading: profileWidget,
        title: Text(name,
            style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: Color(0xFF004D40))),
        subtitle:
            Text(dateTime, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing:
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
        onTap: () {
          debugPrint('Appointment Tapped: $name');
        },
      ),
    );
  }
}