// lib/screens/video_consultation_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoConsultationScreen extends StatefulWidget {
  final String appointmentId;

  const VideoConsultationScreen({super.key, required this.appointmentId});

  @override
  State<VideoConsultationScreen> createState() => _VideoConsultationScreenState();
}

class _VideoConsultationScreenState extends State<VideoConsultationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _appointmentData;
  bool _isDoctor = false;

  @override
  void initState() {
    super.initState();
    _loadAppointmentData();
    _checkIfUserIsDoctor();
  }

  Future<void> _checkIfUserIsDoctor() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _isDoctor = userData['role'] == 'doctor';
          });
        }
      }
    }
  }

  Future<void> _loadAppointmentData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      DocumentSnapshot appointmentDoc = await _firestore
          .collection('appointments')
          .doc(widget.appointmentId)
          .get();

      if (!appointmentDoc.exists) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = "Appointment not found.";
          });
        }
        return;
      }

      Map<String, dynamic> appointmentData = appointmentDoc.data() as Map<String, dynamic>;
      
      // Check if current user is authorized to view this appointment
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = "User not authenticated.";
          });
        }
        return;
      }

      bool isAuthorized = currentUser.uid == appointmentData['userId'] || 
                         currentUser.uid == appointmentData['doctorId'];
      
      if (!isAuthorized) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = "You do not have permission to view this appointment.";
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _appointmentData = appointmentData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading appointment data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to load appointment data: ${e.toString()}"; 
        });
      }
    }
  }

  Future<void> _addGoogleMeetLink() async {
    if (_appointmentData == null) return;

    // Generate a Google Meet link
    // In a real app, you might want to use Google Calendar API to create a meeting
    // For this example, we'll create a simple meet.google.com link with a random ID
    String meetId = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    String meetLink = "https://meet.google.com/$meetId";

    try {
      await _firestore.collection('appointments').doc(widget.appointmentId).update({
        'videoConsultationLink': meetLink,
        'isVideoLinkShared': true,
        'status': 'video_link_added',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video consultation link added successfully!')),
        );
        _loadAppointmentData(); // Refresh the data
      }
    } catch (e) {
      debugPrint("Error adding Google Meet link: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add video link: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _launchMeetLink() async {
    if (_appointmentData == null || _appointmentData!['videoConsultationLink'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video link available for this appointment')),
      );
      return;
    }

    final Uri url = Uri.parse(_appointmentData!['videoConsultationLink']);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String appointmentDateFormatted = '';
    if (_appointmentData != null && _appointmentData!['appointmentDate'] != null && _appointmentData!['appointmentTime'] != null) {
      String dateStr = _appointmentData!['appointmentDate'];
      String timeStr = _appointmentData!['appointmentTime'];
      appointmentDateFormatted = "$dateStr at $timeStr";
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Consultation', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6EB6B4),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))))
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
                ))
              : _appointmentData == null
                  ? const Center(child: Text('Appointment data not available.'))
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _appointmentData!['category'] ?? _appointmentData!['doctorSpeciality'] ?? 'Consultation',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(Icons.calendar_today_outlined, "Date & Time", appointmentDateFormatted),
                                  _buildInfoRow(Icons.person_outline, "Doctor", _appointmentData!['doctorName'] ?? 'N/A'),
                                  _buildInfoRow(Icons.medical_services_outlined, "Speciality", _appointmentData!['doctorSpeciality'] ?? 'N/A'),
                                  _buildInfoRow(Icons.info_outline, "Status", _appointmentData!['status']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'N/A'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_appointmentData!['isVideoLinkShared'] == true && _appointmentData!['videoConsultationLink'] != null) ...[  
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Video Consultation Link",
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _appointmentData!['videoConsultationLink'],
                                      style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.video_call),
                                        label: const Text('Join Meeting'),
                                        onPressed: _launchMeetLink,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else if (_isDoctor) ...[  
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add_link),
                                label: const Text('Add Google Meet Link'),
                                onPressed: _addGoogleMeetLink,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ] else ...[  
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'The doctor has not added a video consultation link yet. Please check back later.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}