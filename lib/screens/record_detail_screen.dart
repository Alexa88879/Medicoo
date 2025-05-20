// lib/screens/record_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// import 'package:flutter_svg/flutter_svg.dart'; // Removed unused import
// import '../models/doctor_model.dart'; 
// import '../models/record_models.dart'; 

class RecordDetailScreen extends StatefulWidget {
  final String recordId; // This will be the appointmentId

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
  List<DocumentSnapshot> _prescriptions = [];
  List<DocumentSnapshot> _labReports = []; // From medical_reports
  // List<DocumentSnapshot> _therapies = []; // Placeholder

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
      if (mounted) { // Check mounted before setState
        setState(() {
          _isLoading = false;
          _error = "User not authenticated.";
        });
      }
      return;
    }

    try {
      // Fetch appointment details
      _appointmentData = await _firestore.collection('appointments').doc(widget.recordId).get();

      if (mounted && !_appointmentData!.exists) { // Check mounted before setState
        setState(() {
          _isLoading = false;
          _error = "Record not found.";
        });
        return;
      }

      // Fetch linked prescriptions
      QuerySnapshot prescriptionSnapshot = await _firestore
          .collection('prescriptions')
          .where('appointmentId', isEqualTo: widget.recordId)
          .where('userId', isEqualTo: currentUser.uid) 
          .get();
      _prescriptions = prescriptionSnapshot.docs;

      // Fetch linked lab reports (from medical_reports)
      QuerySnapshot labReportSnapshot = await _firestore
          .collection('medical_reports')
          .where('linkedAppointmentId', isEqualTo: widget.recordId)
          .where('userId', isEqualTo: currentUser.uid) 
          .where('reportType', isEqualTo: 'lab_test') 
          .get();
      _labReports = labReportSnapshot.docs;
      
      // TODO: Fetch therapy data if schema is defined

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading record details: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to load record details.";
        });
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? appointmentDetails =
        _appointmentData?.data() as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Details', style: TextStyle(color: Color(0xFF00695C))),
        backgroundColor: Colors.white,
        elevation: 1.0,
        iconTheme: const IconThemeData(color: Color(0xFF00695C)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : appointmentDetails == null
                  ? const Center(child: Text('Record data not available.'))
                  : ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        // Doctor Section
                        _buildSectionTitle('Doctor'),
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: Icon(Icons.person_outline, color: Theme.of(context).primaryColor),
                            title: Text(appointmentDetails['doctorName'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(appointmentDetails['doctorSpeciality'] ?? 'N/A'),
                          ),
                        ),

                        // Lab Test Reports Section
                        _buildSectionTitle('Lab Test Reports'),
                        if (_labReports.isEmpty)
                          const Text('No lab reports found for this record.', style: TextStyle(color: Colors.grey)),
                        ..._labReports.map((reportDoc) {
                          Map<String, dynamic> reportData = reportDoc.data() as Map<String, dynamic>;
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(Icons.science_outlined, color: Theme.of(context).primaryColor),
                              title: Text(reportData['reportName'] ?? 'Unnamed Report'),
                              subtitle: Text('Date: ${reportData['dateOfReport'] != null ? DateFormat('dd MMM, yyyy').format((reportData['dateOfReport'] as Timestamp).toDate()) : 'N/A'}'),
                              trailing: IconButton(
                                icon: Icon(Icons.visibility_outlined, color: Colors.grey[600]),
                                onPressed: () {
                                  // TODO: Implement view report (e.g., open PDF from reportData['fileUrl'])
                                   if (mounted) { // Guard context use
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('View report (Not Implemented)')), // Removed const
                                    );
                                   }
                                },
                              ),
                            ),
                          );
                        }).toList(),

                        // Prescribed Medicines Section
                        _buildSectionTitle('Prescribed Medicines'),
                        if (_prescriptions.isEmpty)
                           const Text('No prescriptions found for this record.', style: TextStyle(color: Colors.grey)),
                        ..._prescriptions.map((prescDoc) {
                           Map<String, dynamic> prescData = prescDoc.data() as Map<String, dynamic>;
                           List<dynamic> medications = prescData['medications'] ?? [];
                           return Card(
                             elevation: 1,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                             margin: const EdgeInsets.only(bottom: 8),
                             child: Padding(
                               padding: const EdgeInsets.all(12.0),
                               child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Prescription from Dr. ${prescData['doctorName'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.w500)),
                                  Text("Date: ${prescData['issueDate'] != null ? DateFormat('dd MMM, yyyy').format((prescData['issueDate'] as Timestamp).toDate()) : 'N/A'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  const Divider(),
                                  if (medications.isEmpty) const Text("No medications listed."),
                                  ...medications.map((med) {
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.medication_outlined, size: 20, color: Theme.of(context).primaryColor),
                                      title: Text(med['medicineName'] ?? 'N/A'),
                                      subtitle: Text(
                                        "Dosage: ${med['dosage'] ?? 'N/A'}, Frequency: ${med['frequency'] ?? 'N/A'}, Duration: ${med['duration'] ?? 'N/A'}"
                                      ),
                                    );
                                  }).toList(),
                                ],
                               ),
                             ),
                           );
                        }),
                        
                        // Therapy Section (Placeholder)
                        _buildSectionTitle('Therapy'),
                        Card( // This Card can be const if its children are const or not dependent on instance state
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                          child: const ListTile(
                            leading: Icon(Icons.self_improvement_outlined), 
                            title: Text('Therapy details (Not Implemented)'),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
