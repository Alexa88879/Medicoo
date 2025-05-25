import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'video_consultation_screen.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final String appointmentId;

  const AppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _appointmentData;

  @override
  void initState() {
    super.initState();
    _loadAppointmentData();
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

  void _navigateToVideoConsultation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoConsultationScreen(
          appointmentId: widget.appointmentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String appointmentDateFormatted = '';
    if (_appointmentData != null) {
      if (_appointmentData!['dateTimeFull'] != null && _appointmentData!['dateTimeFull'] is Timestamp) {
        DateTime dt = (_appointmentData!['dateTimeFull'] as Timestamp).toDate();
        appointmentDateFormatted = DateFormat('EEE, dd MMM, yyyy  •  hh:mm a').format(dt);
      } else if (_appointmentData!['appointmentDate'] != null && _appointmentData!['appointmentTime'] != null) {
        String dateStr = _appointmentData!['appointmentDate'];
        String timeStr = _appointmentData!['appointmentTime'];
        appointmentDateFormatted = "$dateStr at $timeStr";
      }
    }

    bool isVideoAppointment = _appointmentData != null && 
                            (_appointmentData!['appointmentType'] == 'video' || 
                             _appointmentData!['bookingType'] == 'video');

    bool hasVideoLink = _appointmentData != null && 
                       _appointmentData!['isVideoLinkShared'] == true && 
                       _appointmentData!['videoConsultationLink'] != null;

    bool isConfirmed = _appointmentData != null && 
                      (_appointmentData!['status'] == 'confirmed' || 
                       _appointmentData!['status'] == 'video_link_added');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details', style: TextStyle(color: Colors.white)),
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
                  : SingleChildScrollView(
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
                                    _appointmentData!['category'] ?? _appointmentData!['doctorSpeciality'] ?? 'Appointment',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildInfoRow(Icons.person_outline, "Doctor", _appointmentData!['doctorName'] ?? 'N/A'),
                                  _buildInfoRow(Icons.medical_services_outlined, "Speciality", _appointmentData!['doctorSpeciality'] ?? 'N/A'),
                                  _buildInfoRow(Icons.calendar_today_outlined, "Date & Time", appointmentDateFormatted),
                                  _buildInfoRow(Icons.info_outline, "Status", _getStatusText(_appointmentData!['status'])),
                                  if (_appointmentData!['symptoms'] != null && _appointmentData!['symptoms'].toString().isNotEmpty)
                                    _buildInfoRow(Icons.healing_outlined, "Symptoms", _appointmentData!['symptoms']),
                                  if (_appointmentData!['notes'] != null && _appointmentData!['notes'].toString().isNotEmpty)
                                    _buildInfoRow(Icons.note_outlined, "Notes", _appointmentData!['notes']),
                                ],
                              ),
                            ),
                          ),
                          
                          if (isVideoAppointment) ...[  
                            const SizedBox(height: 20),
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Video Consultation",
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 12),
                                    if (hasVideoLink && isConfirmed) ...[  
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
                                    ] else if (isConfirmed) ...[  
                                      const Text(
                                        'The doctor has not added a video consultation link yet. Please check back later.',
                                        style: TextStyle(fontSize: 16, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Check for Video Link'),
                                          onPressed: _loadAppointmentData,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ),
                                    ] else ...[  
                                      const Text(
                                        'Your appointment is not confirmed yet. Once confirmed, the doctor will add a video consultation link.',
                                        style: TextStyle(fontSize: 16, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 20),
                          if (isVideoAppointment && isConfirmed) ...[  
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.video_call),
                                label: const Text('Go to Video Consultation'),
                                onPressed: _navigateToVideoConsultation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }

  String _getStatusText(String? status) {
    if (status == null) return 'N/A';
    
    String displayStatus = status.replaceAll('_', ' ');
    return displayStatus.split(' ').map((word) => 
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : ''
    ).join(' ');
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