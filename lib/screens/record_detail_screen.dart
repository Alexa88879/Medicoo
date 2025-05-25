// lib/screens/record_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prescription_model.dart';
import '../secrets.dart';

// Data class for structured diet advice (assuming it's defined here or imported)
class StructuredDietAdvice {
  final List<String> beneficialNutrients;
  final List<String> foodsToEat;
  final List<String> foodsToAvoid;
  final List<String> generalTips;

  StructuredDietAdvice({
    required this.beneficialNutrients,
    required this.foodsToEat,
    required this.foodsToAvoid,
    required this.generalTips,
  });

  factory StructuredDietAdvice.fromJson(Map<String, dynamic> json) {
    List<String> cleanList(List<dynamic>? rawList) {
      if (rawList == null) return [];
      return rawList.map((item) {
        String strItem = item.toString();
        strItem = strItem.replaceFirst(RegExp(r'^[\*\-\–\•]\s*'), '');
        strItem = strItem.replaceFirst(RegExp(r'^\d+\.\s*'), '');
        return strItem.trim();
      }).toList();
    }
    return StructuredDietAdvice(
      beneficialNutrients: cleanList(json['beneficialNutrients']),
      foodsToEat: cleanList(json['foodsToEat']),
      foodsToAvoid: cleanList(json['foodsToAvoid']),
      generalTips: cleanList(json['generalTips']),
    );
  }
}


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
  bool _isRecordCompleted = false;

  DocumentSnapshot? _appointmentData;
  List<Prescription> _prescriptions = [];
  List<DocumentSnapshot> _labReports = [];

  final Map<String, StructuredDietAdvice?> _dietAdviceMap = {};
  final Map<String, bool> _isFetchingDietAdviceMap = {};
  final Map<String, String?> _dietAdviceErrorMap = {};

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
      _isRecordCompleted = false;
      _dietAdviceMap.clear();
      _isFetchingDietAdviceMap.clear();
      _dietAdviceErrorMap.clear();
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
    debugPrint("[RecordDetailScreen] Current User UID: ${currentUser.uid}");
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
          _appointmentData = null;
        });
        return;
      }

      if (appointmentDetails['status'] == 'completed') {
        if (mounted) {
          setState(() {
            _isRecordCompleted = true;
            debugPrint("[RecordDetailScreen] Record status is 'completed'. _isRecordCompleted set to true.");
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isRecordCompleted = false;
            debugPrint("[RecordDetailScreen] Record status is '${appointmentDetails['status']}'. _isRecordCompleted set to false.");
          });
        }
      }

      if (_isRecordCompleted) {
        debugPrint("[RecordDetailScreen] Record is completed. Fetching prescriptions and lab reports.");
        QuerySnapshot prescriptionSnapshot = await _firestore
            .collection('prescriptions')
            .where('appointmentId', isEqualTo: widget.recordId)
            .where('patientId', isEqualTo: currentUser.uid)
            .orderBy('issuedDate', descending: true)
            .get();

        if (prescriptionSnapshot.docs.isNotEmpty) {
          _prescriptions = prescriptionSnapshot.docs
              .map((doc) => Prescription.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
              .toList();
        } else {
          _prescriptions = [];
        }

        QuerySnapshot labReportSnapshot = await _firestore
            .collection('medical_reports')
            .where('linkedAppointmentId', isEqualTo: widget.recordId)
            .where('userId', isEqualTo: currentUser.uid)
            .where('reportType', isEqualTo: 'lab_test')
            .get();
        _labReports = labReportSnapshot.docs;
      } else {
        _prescriptions = [];
        _labReports = [];
        debugPrint("[RecordDetailScreen] Record is not completed. Skipping fetch for prescriptions and lab reports.");
      }

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

  Future<void> _getDietAdviceFromGemini(Prescription prescription) async {
    if (!mounted) return;
    final prescriptionId = prescription.id;

    if (geminiApiKey.isEmpty || geminiApiKey == "YOUR_GEMINI_API_KEY_HERE") {
        debugPrint("[RecordDetailScreen] Gemini API Key is not set in secrets.dart");
        if (mounted) {
            setState(() {
                _dietAdviceErrorMap[prescriptionId] = "Diet advice feature is not available. API key missing.";
                _isFetchingDietAdviceMap[prescriptionId] = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Diet advice feature is currently unavailable."), backgroundColor: Colors.orange),
            );
        }
        return;
    }

    setState(() {
      _isFetchingDietAdviceMap[prescriptionId] = true;
      _dietAdviceMap[prescriptionId] = null;
      _dietAdviceErrorMap[prescriptionId] = null;
    });

    String diagnosis = prescription.diagnosis ?? "No specific diagnosis provided.";
    String currentAdvice = prescription.advice ?? "No specific advice provided by doctor.";
    
    String prompt = "You are an AI medical assistant. Based on the diagnosis: '$diagnosis' and current medical advice: '$currentAdvice', provide diet advice for a patient as a doctor would. Structure your response as JSON with the following keys: 'beneficialNutrients' (array of short strings, max 5 items), 'foodsToEat' (array of short strings, max 5 items), 'foodsToAvoid' (array of short strings, max 5 items), and 'generalTips' (array of very short, actionable general dietary tips, max 3 items). Ensure each string item is a direct statement suitable for a bullet point and does not contain any markdown characters like asterisks or hyphens. Keep the overall advice concise and easy to understand. Do not provide medical disclaimers in the JSON output.";

    debugPrint("[RecordDetailScreen] Gemini Prompt for prescription $prescriptionId: $prompt");

    try {
      final chatHistory = [{"role": "user", "parts": [{"text": prompt}]}];
      final payload = {
          "contents": chatHistory,
          "generationConfig": {
              "responseMimeType": "application/json",
              "responseSchema": {
                  "type": "OBJECT",
                  "properties": {
                    "beneficialNutrients": { "type": "ARRAY", "description": "List of specific nutrients beneficial (max 5 items, short strings).", "items": { "type": "STRING" }},
                    "foodsToEat": { "type": "ARRAY", "description": "List of specific foods to eat (max 5 items, short strings).", "items": { "type": "STRING" }},
                    "foodsToAvoid": { "type": "ARRAY", "description": "List of specific foods to avoid (max 5 items, short strings).", "items": { "type": "STRING" }},
                    "generalTips": { "type": "ARRAY", "description": "Short, actionable general dietary tips (max 3 items, very short strings).", "items": { "type": "STRING"}}
                  },
                  "required": ["beneficialNutrients", "foodsToEat", "foodsToAvoid", "generalTips"]
              }
          }
      };
      
      final apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey";

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        debugPrint("[RecordDetailScreen] Gemini API Response: $result");
        if (result['candidates'] != null && result['candidates'].isNotEmpty && result['candidates'][0]['content'] != null && result['candidates'][0]['content']['parts'] != null && result['candidates'][0]['content']['parts'].isNotEmpty) {
          final String jsonText = result['candidates'][0]['content']['parts'][0]['text'];
          final Map<String, dynamic> jsonData = jsonDecode(jsonText);
          if (mounted) {
            setState(() {
              _dietAdviceMap[prescriptionId] = StructuredDietAdvice.fromJson(jsonData);
            });
          }
        } else {
          throw Exception("Unexpected Gemini API response structure or no content.");
        }
      } else {
        debugPrint("[RecordDetailScreen] Gemini API Error: ${response.statusCode} - ${response.body}");
        throw Exception("Failed to get diet advice from Gemini. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("[RecordDetailScreen] Error calling Gemini API or parsing JSON: $e");
      if (mounted) {
        setState(() {
          _dietAdviceErrorMap[prescriptionId] = "Sorry, couldn't fetch or parse diet advice. Please try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingDietAdviceMap[prescriptionId] = false;
        });
      }
    }
  }

  Widget _buildSectionTitle(String title, {IconData? icon, double topPadding = 24.0, double bottomPadding = 10.0}) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
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
      if (mounted) {
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
                  ? const Center(child: Text('Appointment data not available.'))
                  : RefreshIndicator(
                      onRefresh: _loadRecordDetails,
                      color: Theme.of(context).primaryColor,
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          if (!_isRecordCompleted && !_isLoading)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Card(
                                color: Colors.orange[50],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(
                                    "Note: This appointment is not marked as 'completed'. Advice/Notes and other detailed information may not be final or available.",
                                    style: TextStyle(color: Colors.orange[800], fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          _buildAppointmentInfoCard(appointmentDetails, appointmentDateFormatted, isRecordCompleted: _isRecordCompleted),
                          
                          if (appointmentDetails['medicalReportUrl'] != null &&
                              appointmentDetails['medicalReportUrl'].isNotEmpty) ...[
                            _buildSectionTitle('Uploaded Medical Report', icon: Icons.description_outlined),
                            Card(
                              elevation: 1.5,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent, size: 30),
                                title: Text(
                                  appointmentDetails['medicalReportFileName'] ?? 'View Medical Report',
                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                                ),
                                subtitle: Text('Tap to view/download', style: TextStyle(color: Colors.grey[600])),
                                trailing: Icon(Icons.open_in_new_rounded, color: Theme.of(context).primaryColor, size: 24),
                                onTap: () => _launchURL(appointmentDetails['medicalReportUrl']),
                              ),
                            ),
                          ],
                          
                          // --- Video Consultation Link Section REMOVED ---
                          // The following block has been removed:
                          // if (_isRecordCompleted && wasVideoAppointment && videoLink != null && videoLink.isNotEmpty && videoLinkShared) ...[
                          //   _buildSectionTitle('Video Consultation Link', icon: Icons.videocam_outlined),
                          //   Card( /* ... */ ),
                          // ] else if (_isRecordCompleted && wasVideoAppointment) ...[
                          //    _buildSectionTitle('Video Consultation Link', icon: Icons.videocam_off_outlined),
                          //    Padding( /* ... */ ),
                          // ],
                          // --- End of REMOVED Video Consultation Link Section ---

                          if (_isRecordCompleted) ...[
                            _buildLabReportsSection(),
                            _buildPrescriptionsSection(),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildAppointmentInfoCard(Map<String, dynamic> appointmentDetails, String appointmentDateFormatted, {required bool isRecordCompleted}) {
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
            
            if (isRecordCompleted) ...[
              if (appointmentDetails['diagnosis'] != null && appointmentDetails['diagnosis'].isNotEmpty)
                 _buildInfoRow(Icons.health_and_safety_outlined, "Diagnosis", appointmentDetails['diagnosis']),
              if (appointmentDetails['notes'] != null && appointmentDetails['notes'].isNotEmpty)
                 _buildInfoRow(Icons.notes_outlined, "Advice/Notes (Appointment)", appointmentDetails['notes']),
            ],
            _buildInfoRow(Icons.info_outline, "Status", appointmentDetails['status']?.toString().capitalizeFirstLetter() ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildLabReportsSection() {
    if (_isLoading && _labReports.isEmpty) return const SizedBox.shrink();
    if (_labReports.isEmpty && !_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Lab Test Reports', icon: Icons.science_outlined),
          const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 10.0), child: Text('No lab reports found for this completed record.', style: TextStyle(color: Colors.grey)))),
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
    if (_isLoading && _prescriptions.isEmpty) return const SizedBox.shrink();
    if (_prescriptions.isEmpty && !_isLoading) {
       return Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           _buildSectionTitle('Prescribed Medicines', icon: Icons.medication_outlined),
           const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 10.0), child: Text('No prescriptions found for this completed record.', style: TextStyle(color: Colors.grey)))),
         ],
       );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Prescribed Medicines', icon: Icons.medication_outlined),
        ..._prescriptions.map((prescription) {
          final prescriptionId = prescription.id;
          final bool isFetchingAdvice = _isFetchingDietAdviceMap[prescriptionId] ?? false;
          final StructuredDietAdvice? structuredDietAdvice = _dietAdviceMap[prescriptionId];
          final String? dietAdviceError = _dietAdviceErrorMap[prescriptionId];

          String issueDateFormatted = DateFormat('dd MMM, yy').format(prescription.issueDate.toDate());
          return Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Prescription from Dr. ${prescription.doctorName}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: Color(0xFF004D40))),
                  const SizedBox(height: 2),
                  Text("Issued on: $issueDateFormatted", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  if (prescription.diagnosis != null && prescription.diagnosis!.isNotEmpty) ...[
                     const SizedBox(height: 6),
                     _buildDetailItem(icon: Icons.medical_information_outlined, label: "Prescription Diagnosis", value: prescription.diagnosis!),
                  ],
                  if (prescription.notes != null && prescription.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildDetailItem(icon: Icons.speaker_notes_outlined, label: "Prescription Notes", value: prescription.notes!),
                  ],
                  if (prescription.advice != null && prescription.advice!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildDetailItem(icon: Icons.lightbulb_outline, label: "Prescription Advice", value: prescription.advice!),
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
                        final med = prescription.medications[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Container(
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
                  const SizedBox(height: 16),
                  if ((prescription.diagnosis != null && prescription.diagnosis!.isNotEmpty) ||
                      (prescription.advice != null && prescription.advice!.isNotEmpty)) ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.restaurant_menu_outlined, size: 18),
                        label: Text(structuredDietAdvice == null && !isFetchingAdvice ? 'Get Diet Advice' : 'Refresh Diet Advice'),
                        onPressed: isFetchingAdvice ? null : () => _getDietAdviceFromGemini(prescription),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isFetchingAdvice)
                        const Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))),
                        ))
                      else if (dietAdviceError != null)
                         Padding(
                           padding: const EdgeInsets.symmetric(vertical: 8.0),
                           child: Text(dietAdviceError, style: TextStyle(color: Colors.red.shade700, fontSize: 14)),
                         )
                      else if (structuredDietAdvice != null)
                        _buildStructuredDietAdviceUI(structuredDietAdvice),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStructuredDietAdviceUI(StructuredDietAdvice advice) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.3))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Text(
              "AI Diet Suggestions",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColorDark,
              ),
            ),
          ),
          if (advice.beneficialNutrients.isNotEmpty)
            _buildDietAdviceCategory("Beneficial Nutrients", advice.beneficialNutrients, Icons.spa_outlined, Colors.green[600]!),
          if (advice.foodsToEat.isNotEmpty)
            _buildDietAdviceCategory("Foods to Include", advice.foodsToEat, Icons.check_circle_outline, Colors.blue[600]!),
          if (advice.foodsToAvoid.isNotEmpty)
            _buildDietAdviceCategory("Foods to Limit/Avoid", advice.foodsToAvoid, Icons.remove_circle_outline, Colors.red[600]!),
           if (advice.generalTips.isNotEmpty)
            _buildDietAdviceCategory("General Dietary Tips", advice.generalTips, Icons.info_outline_rounded, Colors.orange[700]!),
        ],
      ),
    );
  }

  Widget _buildDietAdviceCategory(String title, List<String> items, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[800]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 5.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                      child: Icon(Icons.fiber_manual_record, size: 8, color: Colors.grey[600]),
                    ),
                    Expanded(child: Text(item, style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4))),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
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
