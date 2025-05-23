// lib/screens/records_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/record_models.dart'; // Your summary model
import 'record_detail_screen.dart'; // The detail screen

class RecordsListScreen extends StatefulWidget {
  const RecordsListScreen({super.key});

  @override
  State<RecordsListScreen> createState() => _RecordsListScreenState();
}

class _RecordsListScreenState extends State<RecordsListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _selectedFilter = 'Lifetime'; // Default filter
  final List<String> _filterOptions = ['Lifetime', 'Last 6 Months', 'Last Year']; // Removed 'Custom Range' for now

  Stream<List<MedicalRecordSummary>>? _recordsStream;
  Map<String, dynamic>? _userData;
  bool _isUserDataLoading = true;


  @override
  void initState() {
    super.initState();
    _fetchUserDataAndSetupStream();
  }

  Future<void> _fetchUserDataAndSetupStream() async {
    if (!mounted) return;
    setState(() => _isUserDataLoading = true);

    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (mounted && userDoc.exists) {
          _userData = userDoc.data() as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint("Error fetching user data for records: $e");
        // Handle error if needed, e.g., show a snackbar
      }
    }
    if (mounted) {
      setState(() => _isUserDataLoading = false);
    }
    _setupRecordsStream(); // Setup stream after fetching user data (or even if it fails/no user)
  }


  void _setupRecordsStream() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _recordsStream = Stream.value([]));
      return;
    }

    Query query = _firestore
        .collection('appointments')
        .where('userId', isEqualTo: currentUser.uid) // Securely fetch for current user
        .orderBy('dateTimeFull', descending: true);

    DateTime now = DateTime.now();
    switch (_selectedFilter) {
      case 'Last 6 Months':
        query = query.where('dateTimeFull', isGreaterThanOrEqualTo: Timestamp.fromDate(now.subtract(const Duration(days: 180))));
        break;
      case 'Last Year':
        query = query.where('dateTimeFull', isGreaterThanOrEqualTo: Timestamp.fromDate(now.subtract(const Duration(days: 365))));
        break;
      case 'Lifetime':
      default:
        // No additional date filter
        break;
    }

    if (mounted) {
      setState(() {
        _recordsStream = query.snapshots().map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            Timestamp eventTimestamp = data['dateTimeFull'] ?? Timestamp.now();
            DateTime eventDate = eventTimestamp.toDate();
            
            String patientAgeAtEventStr = "N/A";
            if (_userData != null && _userData!['age'] != null) {
               patientAgeAtEventStr = _userData!['age'].toString();
            }
            // For more accurate age at event, you'd need user's DOB
            // and calculate age based on eventDate and DOB.

            return MedicalRecordSummary(
              id: doc.id, // This is the appointmentId
              diseaseOrCategory: data['category'] ?? data['doctorSpeciality'] ?? 'N/A',
              year: DateFormat('yyyy').format(eventDate),
              period: DateFormat('dd MMM, yyyy').format(eventDate), // Using full date for period
              patientAgeAtEvent: patientAgeAtEventStr,
              eventTimestamp: eventTimestamp,
            );
          }).toList();
        });
      });
    }
  }
  
  void _onFilterChanged(String? newFilter) {
    if (newFilter != null && newFilter != _selectedFilter) {
      if (mounted) {
        setState(() {
          _selectedFilter = newFilter;
        });
      }
      _setupRecordsStream();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Records', style: TextStyle(color: Color(0xFF00695C))),
        backgroundColor: Colors.white,
        elevation: 1.0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedFilter,
                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                  elevation: 16,
                  style: TextStyle(color: Colors.grey[800], fontSize: 16),
                  onChanged: _onFilterChanged,
                  items: _filterOptions.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MedicalRecordSummary>>(
              stream: _recordsStream,
              builder: (context, snapshot) {
                if ((snapshot.connectionState == ConnectionState.waiting && _recordsStream == null) || _isUserDataLoading) {
                  return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No records found for the selected filter.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ));
                }

                List<MedicalRecordSummary> records = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.diseaseOrCategory,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF00695C)),
                            ),
                            const SizedBox(height: 8),
                            _buildRecordInfoRow('Date:', record.period), // Period is now the full date
                            _buildRecordInfoRow('Year:', record.year),
                            _buildRecordInfoRow('Patient Age (at event):', record.patientAgeAtEvent ?? 'N/A'),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.arrow_forward, size: 16),
                                label: const Text('View Details'),
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => RecordDetailScreen(recordId: record.id),
                                  ));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)
                                  ),
                                  textStyle: const TextStyle(fontSize: 14)
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87))),
        ],
      ),
    );
  }
}
