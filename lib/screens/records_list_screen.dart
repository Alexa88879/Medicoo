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
  final List<String> _filterOptions = ['Lifetime', 'Last 6 Months', 'Last Year', 'Custom Range']; // Example filters

  Stream<List<MedicalRecordSummary>>? _recordsStream;
  Map<String, dynamic>? _userData;


  @override
  void initState() {
    super.initState();
    debugPrint("[RecordsListScreen] initState called.");
    _fetchUserDataAndSetupStream();
  }

  Future<void> _fetchUserDataAndSetupStream() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
      } catch (e) {
        debugPrint('Error fetching user data: $e');
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (mounted && userDoc.exists) {
          _userData = userDoc.data() as Map<String, dynamic>;
        };
      }
    }
    _setupRecordsStream(); // Setup stream after fetching user data (or even if it fails)
  }


  void _setupRecordsStream() {
    User? currentUser = _auth.currentUser;
    debugPrint("[RecordsListScreen] _setupRecordsStream called. Filter: $_selectedFilter, User: ${currentUser?.uid}");

    if (currentUser == null) {
      setState(() => _recordsStream = Stream.value([])); // Empty stream if no user
      return;
    }
    
    if(mounted) {
      setState(() {
// Remove this line since _isSettingUpStream is not defined
        _recordsStream = null; 
      });
    }

    Query query = _firestore
        .collection('appointments')
        .where('userId', isEqualTo: currentUser.uid)
        // .where('status', whereIn: ['completed', 'cancelled']) // Consider only completed/cancelled appointments as "records"
        .orderBy('dateTimeFull', descending: true); // Most recent first

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
        // No additional date filter for lifetime
        break;
    }
    // TODO: Implement 'Custom Range' filter with date pickers

    setState(() {
      _recordsStream = query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          Timestamp eventTimestamp = data['dateTimeFull'] ?? Timestamp.now();
          DateTime eventDate = eventTimestamp.toDate();
          
          String patientAgeAtEventStr = "N/A";
          if (_userData != null && _userData!['age'] != null) { // Using current age for simplicity
             patientAgeAtEventStr = _userData!['age'].toString();
          }
          // For more accuracy, if you store user's DOB:
          // if (_userData != null && _userData!['birthDate'] is Timestamp) {
          //   DateTime birthDate = (_userData!['birthDate'] as Timestamp).toDate();
          //   int age = eventDate.year - birthDate.year;
          //   if (eventDate.month < birthDate.month || (eventDate.month == birthDate.month && eventDate.day < birthDate.day)) {
          //     age--;
          //   }
          //  patientAgeAtEventStr = age.toString();
          // }


          return MedicalRecordSummary(
            id: doc.id,
            diseaseOrCategory: data['category'] ?? data['doctorSpeciality'] ?? 'N/A',
            year: DateFormat('yyyy').format(eventDate),
            period: DateFormat('dd MMM, yyyy').format(eventDate),
            patientAgeAtEvent: patientAgeAtEventStr,
            eventTimestamp: eventTimestamp,
          );
        }).toList();
      });
    });
  }
  
  void _onFilterChanged(String? newFilter) {
    if (newFilter != null && newFilter != _selectedFilter) {
      setState(() {
        _selectedFilter = newFilter;
      });
      _setupRecordsStream(); // Re-fetch/re-filter data
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[RecordsListScreen] Build method called.");
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Records', style: TextStyle(color: Color(0xFF00695C))),
        backgroundColor: Colors.white,
        elevation: 1.0,
        automaticallyImplyLeading: false, // No back button as it's a tab
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
                if (snapshot.connectionState == ConnectionState.waiting && _userData == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No records found.'));
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
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.diseaseOrCategory,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF00695C)),
                            ),
                            const SizedBox(height: 8),
                            _buildRecordInfoRow('Year:', record.year),
                            _buildRecordInfoRow('Period:', record.period),
                            _buildRecordInfoRow('Age:', record.patientAgeAtEvent ?? 'N/A'),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute( // Use context from builder
                                    builder: (context) => RecordDetailScreen(recordId: record.id),
                                  ));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)
                                  )
                                ),
                                child: const Text('More'),
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
