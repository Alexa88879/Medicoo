// lib/screens/record_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import '../models/prescription_model.dart'; // Import the common Prescription model

class RecordDetailScreen extends StatefulWidget {
  final String recordId; // This is the appointmentId

  const RecordDetailScreen({super.key, required this.recordId});

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String? _error;

  DocumentSnapshot? _appointmentData;
  List<Prescription> _prescriptions = []; // Use the common Prescription model
  List<DocumentSnapshot> _labReports = [];

  @override
  void initState() {
    super.initState();
    _loadRecordDetails();
  }

  Future<void> _loadRecordDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        debugPrint("[RecordDetailScreen] User not authenticated.");
        setState(() {
          _isLoading = false;
          _error = "User not authenticated. Please login again.";
        });
      }
      return;
    }
    debugPrint("[RecordDetailScreen] Current User UID (for patientId query): ${currentUser.uid}");
    debugPrint("[RecordDetailScreen] Loading record details for appointmentId: ${widget.recordId}");

    try {
      _appointmentData = await _firestore.collection('appointments').doc(widget.recordId).get();
      debugPrint("[RecordDetailScreen] Appointment data fetched. Exists: ${_appointmentData?.exists}");

      if (!mounted) return;

      if (!_appointmentData!.exists) {
        setState(() {
          _isLoading = false;
          _error = "Appointment record not found.";
        });
        return;
      }

      Map<String, dynamic>? appointmentDetails = _appointmentData!.data() as Map<String, dynamic>?;
      if (appointmentDetails == null || appointmentDetails['userId'] != currentUser.uid) {
         debugPrint("[RecordDetailScreen] Permission check: Appointment userId ${appointmentDetails?['userId']} vs Current user ${currentUser.uid}");
         setState(() {
          _isLoading = false;
          _error = "You do not have permission to view this appointment's details.";
        });
         // Optionally clear data if access denied
         // _appointmentData = null; 
         // return; 
      }

      debugPrint("[RecordDetailScreen] Fetching prescriptions for appointmentId: ${widget.recordId}, patientId: ${currentUser.uid}");
      QuerySnapshot prescriptionSnapshot = await _firestore
          .collection('prescriptions')
          .where('appointmentId', isEqualTo: widget.recordId)
          .where('patientId', isEqualTo: currentUser.uid)
          .orderBy('issuedDate', descending: true)
          .get();
          
      debugPrint("[RecordDetailScreen] Found ${prescriptionSnapshot.docs.length} prescription document(s).");
      if (prescriptionSnapshot.docs.isNotEmpty) {
        _prescriptions = prescriptionSnapshot.docs
            .map((doc) => Prescription.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList();
        for (var p in _prescriptions) {
            debugPrint("[RecordDetailScreen] Final Parsed Prescription ID: ${p.id}, Medications count: ${p.medications.length}");
        }
      } else {
        _prescriptions = [];
      }

      debugPrint("[RecordDetailScreen] Fetching lab reports for linkedAppointmentId: ${widget.recordId}, userId: ${currentUser.uid}");
      QuerySnapshot labReportSnapshot = await _firestore
          .collection('medical_reports')
          .where('linkedAppointmentId', isEqualTo: widget.recordId)
          .where('userId', isEqualTo: currentUser.uid) 
          .where('reportType', isEqualTo: 'lab_test')
          .get();
      debugPrint("[RecordDetailScreen] Found ${labReportSnapshot.docs.length} lab reports.");
      _labReports = labReportSnapshot.docs;

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, s) {
      debugPrint("[RecordDetailScreen] Error loading record details: $e");
      debugPrint("[RecordDetailScreen] Stacktrace: $s");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to load record details. Please try again.";
        });
      }
    }
  }

  Widget _buildSectionTitle(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 10.0),
      child: Row(
        children: [
          if (icon != null) Icon(icon, color: Theme.of(context).primaryColor, size: 22),
          if (icon != null) const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColorDark),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? appointmentDetails =
        _appointmentData?.data() as Map<String, dynamic>?;

    String appointmentDateFormatted = "N/A";
    if (appointmentDetails != null && appointmentDetails['dateTimeFull'] is Timestamp) {
      appointmentDateFormatted = DateFormat('EEE, dd MMM, yy  •  hh:mm a').format((appointmentDetails['dateTimeFull'] as Timestamp).toDate());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Details', style: TextStyle(color: Color(0xFF00695C))),
        backgroundColor: Colors.white,
        elevation: 1.0,
        iconTheme: const IconThemeData(color: Color(0xFF00695C)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))))
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
                ))
              : appointmentDetails == null
                  ? const Center(child: Text('Appointment data not available for this record.'))
                  : RefreshIndicator(
                      onRefresh: _loadRecordDetails,
                      color: Theme.of(context).primaryColor,
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          _buildAppointmentInfoCard(appointmentDetails, appointmentDateFormatted),
                          _buildLabReportsSection(),
                          _buildPrescriptionsSection(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildAppointmentInfoCard(Map<String, dynamic> appointmentDetails, String appointmentDateFormatted) {
     return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appointmentDetails['category'] ?? appointmentDetails['doctorSpeciality'] ?? 'Consultation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today_outlined, "Date & Time", appointmentDateFormatted),
            _buildInfoRow(Icons.person_outline, "Doctor", appointmentDetails['doctorName'] ?? 'N/A'),
            _buildInfoRow(Icons.medical_services_outlined, "Speciality", appointmentDetails['doctorSpeciality'] ?? 'N/A'),
            if (appointmentDetails['diagnosis'] != null && appointmentDetails['diagnosis'].isNotEmpty)
               _buildInfoRow(Icons.health_and_safety_outlined, "Diagnosis", appointmentDetails['diagnosis']),
            if (appointmentDetails['notes'] != null && appointmentDetails['notes'].isNotEmpty)
               _buildInfoRow(Icons.notes_outlined, "Consultation Notes", appointmentDetails['notes']),
            _buildInfoRow(Icons.info_outline, "Status", appointmentDetails['status']?.toString().capitalizeFirstLetter() ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildLabReportsSection() {
    if (_isLoading) return const SizedBox.shrink();
    if (_labReports.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Lab Test Reports', icon: Icons.science_outlined),
          const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 10.0), child: Text('No lab reports found for this record.', style: TextStyle(color: Colors.grey)))),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Lab Test Reports', icon: Icons.science_outlined),
        ..._labReports.map((reportDoc) {
          Map<String, dynamic> reportData = reportDoc.data() as Map<String, dynamic>;
          String reportDateFormatted = "N/A";
          if (reportData['dateOfReport'] != null && reportData['dateOfReport'] is Timestamp) {
            reportDateFormatted = DateFormat('dd MMM, yy').format((reportData['dateOfReport'] as Timestamp).toDate());
          }
          return Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(Icons.assignment_outlined, color: Theme.of(context).primaryColor, size: 28),
              title: Text(reportData['reportName'] ?? 'Unnamed Report', style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('Date: $reportDateFormatted\n${reportData['summaryOrKeyFindings'] ?? ''}'),
              isThreeLine: (reportData['summaryOrKeyFindings'] ?? '').isNotEmpty,
              trailing: (reportData['fileUrl'] != null && reportData['fileUrl'].isNotEmpty)
                ? IconButton(
                    icon: Icon(Icons.download_for_offline_outlined, color: Colors.teal[700], size: 26),
                    tooltip: "View/Download Report",
                    onPressed: () => _launchURL(reportData['fileUrl']),
                  )
                : null,
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildPrescriptionsSection() {
    if (_isLoading) return const SizedBox.shrink();
    if (_prescriptions.isEmpty) {
       return Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           _buildSectionTitle('Prescribed Medicines', icon: Icons.medication_outlined),
           const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 10.0), child: Text('No prescriptions found for this record.', style: TextStyle(color: Colors.grey)))),
         ],
       );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Prescribed Medicines', icon: Icons.medication_outlined),
        ..._prescriptions.map((prescription) { // prescription is now Prescription (from model)
          String issueDateFormatted = DateFormat('dd MMM, yy').format(prescription.issueDate.toDate());
          return Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16.0), // Increased padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Prescription from Dr. ${prescription.doctorName}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: Color(0xFF004D40))),
                  const SizedBox(height: 2),
                  Text("Issued on: $issueDateFormatted", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  if (prescription.diagnosis != null && prescription.diagnosis!.isNotEmpty) ...[
                     const SizedBox(height: 6),
                     _buildDetailItem(icon: Icons.medical_information_outlined, label: "Diagnosis", value: prescription.diagnosis!),
                  ],
                  if (prescription.notes != null && prescription.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildDetailItem(icon: Icons.speaker_notes_outlined, label: "Notes", value: prescription.notes!),
                  ],
                  const Divider(height: 24, thickness: 0.8),
                  Text("Medications:", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[800])),
                  const SizedBox(height: 8),
                  if (prescription.medications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text("No medications listed in this prescription.", style: TextStyle(color: Colors.orangeAccent, fontStyle: FontStyle.italic)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: prescription.medications.length,
                      itemBuilder: (context, index) {
                        final med = prescription.medications[index]; // med is now Medication (from model)
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Container( // Added container for better visual separation of meds
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8)
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(med.medicineName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                const SizedBox(height: 2),
                                Text("Dosage: ${med.dosage}", style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                                Text("Frequency: ${med.frequency}", style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                                Text("Duration: ${med.duration}", style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                              ],
                            ),
                          )
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDetailItem({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 18),
          const SizedBox(width: 8),
          Text("$label: ", style: TextStyle(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
        ],
      ),
    );
  }


  Widget _buildInfoRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.teal[600], size: 20),
          const SizedBox(width: 12),
          Text('$label: ', style: TextStyle(fontSize: 15, color: Colors.grey[800], fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 15, color: Colors.grey[700]))),
        ],
      ),
    );
  }
}

extension StringExtensionOnRecordDetail on String {
  String capitalizeFirstLetter() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
