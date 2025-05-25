import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'appointment_detail_screen.dart';

class AllAppointmentsScreen extends StatefulWidget {
  const AllAppointmentsScreen({super.key});

  @override
  State<AllAppointmentsScreen> createState() => _AllAppointmentsScreenState();
}

class _AllAppointmentsScreenState extends State<AllAppointmentsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<DocumentSnapshot> _appointments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAllAppointments();
  }

  Future<void> _fetchAllAppointments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _error = "User not authenticated. Please login again.";
        });
        return;
      }

      QuerySnapshot snapshot = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: currentUser.uid)
          .where('dateTimeFull', isGreaterThanOrEqualTo: Timestamp.now())
          .where('status', whereIn: ['booked', 'confirmed', 'video_link_added'])
          .orderBy('dateTimeFull', descending: false)
          .get();

      setState(() {
        _appointments = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Error fetching appointments: $e";
      });
    }
  }

  Widget _buildAppointmentItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String name = data['doctorName'] ?? data['labTestName'] ?? data['category'] ?? 'Appointment';
    String dateTimeStr = 'Date/Time N/A';
    String status = data['status'] ?? 'N/A';

    if (data['dateTimeFull'] != null && data['dateTimeFull'] is Timestamp) {
      DateTime dt = (data['dateTimeFull'] as Timestamp).toDate();
      dateTimeStr = DateFormat('EEE, dd MMM, yy  •  hh:mm a').format(dt);
    }

    Color statusColor = Colors.grey;
    String displayStatus = status.replaceAll('_', ' ');
    displayStatus = displayStatus.substring(0, 1).toUpperCase() + displayStatus.substring(1);

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

    Widget profileIconWidget;
    if (data['category'] == 'Lab Test' || data['labTestName'] != null) {
      profileIconWidget = const CircleAvatar(
        backgroundColor: Color(0xFFE0F2F1),
        child: Icon(Icons.biotech, color: Color(0xFF008080)),
      );
    } else if (data['appointmentType'] == 'video') {
      profileIconWidget = const CircleAvatar(
        backgroundColor: Color(0xFFE0F2F1),
        child: Icon(Icons.videocam, color: Color(0xFF008080)),
      );
    } else {
      profileIconWidget = const CircleAvatar(
        backgroundColor: Color(0xFFE0F2F1),
        child: Icon(Icons.person, color: Color(0xFF008080)),
      );
    }

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: Colors.grey[200]!, width: 0.8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: profileIconWidget,
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(dateTimeStr, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                displayStatus,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        onTap: () {
          // Navigate to appointment details screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppointmentDetailScreen(
                appointmentId: doc.id,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Upcoming Appointments'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _appointments.isEmpty
                  ? const Center(child: Text('No upcoming appointments'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _appointments.length,
                      itemBuilder: (context, index) {
                        return _buildAppointmentItem(_appointments[index]);
                      },
                    ),
    );
  }
}