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
  final List<String> _filterOptions = ['Lifetime', 'Last 6 Months', 'Last Year'];
  // New filter for appointment type
  String _selectedAppointmentTypeFilter = 'All'; // 'All', 'In-Person', 'Video'
  final List<String> _appointmentTypeFilterOptions = ['All', 'In-Person', 'Video'];


  Stream<List<MedicalRecordSummary>>? _recordsStream;
  Map<String, dynamic>? _userData;
  bool _isUserDataLoading = true;
  bool _isSettingUpStream = true;

  @override
  void initState() {
    super.initState();
    debugPrint("[RecordsListScreen] initState called.");
    _fetchUserDataAndSetupStream();
  }

  Future<void> _fetchUserDataAndSetupStream() async {
    debugPrint("[RecordsListScreen] _fetchUserDataAndSetupStream called (Refresh or Initial).");
    if (!mounted) return;
    setState(() {
      _isUserDataLoading = true;
      _isSettingUpStream = true; // Reset this flag too
    });

    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (mounted && userDoc.exists) {
          _userData = userDoc.data() as Map<String, dynamic>;
          debugPrint("[RecordsListScreen] User data fetched: ${_userData?['displayName']}");
        } else {
          debugPrint("[RecordsListScreen] User document does not exist for UID: ${currentUser.uid}");
        }
      } catch (e) {
        debugPrint("[RecordsListScreen] Error fetching user data: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load user details: ${e.toString()}')),
          );
        }
      }
    } else {
      debugPrint("[RecordsListScreen] No current user found.");
    }

    if (mounted) {
      setState(() {
        _isUserDataLoading = false;
      });
    }
    _setupRecordsStream(); // Call this after user data is potentially loaded
  }

  void _setupRecordsStream() {
    User? currentUser = _auth.currentUser;
    debugPrint("[RecordsListScreen] _setupRecordsStream called. Date Filter: $_selectedFilter, Type Filter: $_selectedAppointmentTypeFilter, User: ${currentUser?.uid}");

    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _recordsStream = Stream.value([]); // Use Stream.value for an empty stream
          _isSettingUpStream = false;
        });
        debugPrint("[RecordsListScreen] No user, setting empty stream and _isSettingUpStream = false.");
      }
      return;
    }

    if (mounted) {
       // Set _isSettingUpStream to true before starting the stream setup.
      setState(() {
        _isSettingUpStream = true;
        _recordsStream = null; // Clear previous stream to show loading if necessary
      });
    }


    Query query = _firestore
        .collection('appointments')
        .where('userId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'completed') // Filter for completed appointments
        .orderBy('dateTimeFull', descending: true);

    // Apply date filter
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
        // No additional date filter for 'Lifetime'
        break;
    }

    // Apply appointment type filter
    if (_selectedAppointmentTypeFilter == 'Video') {
      query = query.where('appointmentType', isEqualTo: 'video');
    } else if (_selectedAppointmentTypeFilter == 'In-Person') {
      // Assuming 'in_person' or null/missing appointmentType means in-person
      // This might need adjustment based on how you store in-person appointments
      // If 'in_person' is explicitly stored:
      query = query.where('appointmentType', isEqualTo: 'in_person');
      // If in-person appointments might have appointmentType as null or not set:
      // query = query.where('appointmentType', whereIn: [null, 'in_person']);
    }
    // If 'All', no additional type filter is applied.

    debugPrint("[RecordsListScreen] Query configured. Date Filter: $_selectedFilter, Type Filter: $_selectedAppointmentTypeFilter. Includes status 'completed'.");

    Stream<List<MedicalRecordSummary>> newStream = query.snapshots().map((snapshot) {
      debugPrint("[RecordsListScreen] Stream received snapshot with ${snapshot.docs.length} documents for current filters.");

      List<MedicalRecordSummary> summaries = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Timestamp eventTimestamp = data['dateTimeFull'] ?? Timestamp.now(); // Fallback, should always exist
        DateTime eventDate = eventTimestamp.toDate();

        String patientAgeAtEventStr = "N/A";
        if (_userData != null && _userData!['age'] != null) {
           patientAgeAtEventStr = _userData!['age'].toString(); // Consider calculating age at time of event if birthdate is stored
        }

        return MedicalRecordSummary(
          id: doc.id,
          doctorName: data['doctorName'] ?? 'N/A',
          doctorSpecialty: data['doctorSpeciality'] ?? 'N/A',
          year: DateFormat('yyyy').format(eventDate),
          period: DateFormat('dd MMM, yyyy').format(eventDate), // Consistent format
          patientAgeAtEvent: patientAgeAtEventStr,
          eventTimestamp: eventTimestamp,
          // You could add 'appointmentType' to MedicalRecordSummary if you want to display it differently
          // appointmentType: data['appointmentType'] ?? 'In-Person',
        );
      }).toList();

      if (summaries.isNotEmpty) {
          debugPrint("[RecordsListScreen] Mapped to ${summaries.length} summaries. First record ID: ${summaries.first.id}, Timestamp: ${summaries.first.eventTimestamp.toDate()}");
      } else {
          debugPrint("[RecordsListScreen] Mapped to 0 summaries for the current filters.");
      }
      
      // Ensure UI updates happen after the build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isSettingUpStream) {
           setState(() => _isSettingUpStream = false);
        }
      });
      return summaries;
    }).handleError((error) {
        debugPrint("[RecordsListScreen] Error in records stream: $error");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isSettingUpStream) {
              setState(() => _isSettingUpStream = false);
          }
        });
        // Optionally, rethrow or return an empty list on error
        // For example, to show an error message in the UI:
        // throw error; // This would be caught by StreamBuilder's error handler
        return <MedicalRecordSummary>[]; // Or return empty list to show "no records"
    });

    if (mounted) {
      setState(() {
        _recordsStream = newStream;
        // _isSettingUpStream will be set to false inside the stream's map/handleError
      });
    }
  }

  void _onDateFilterChanged(String? newFilter) {
    if (newFilter != null && newFilter != _selectedFilter) {
      debugPrint("[RecordsListScreen] Date Filter changed to: $newFilter");
      if (mounted) {
        setState(() {
          _selectedFilter = newFilter;
        });
      }
      _setupRecordsStream();
    }
  }

   void _onAppointmentTypeFilterChanged(String? newFilter) {
    if (newFilter != null && newFilter != _selectedAppointmentTypeFilter) {
      debugPrint("[RecordsListScreen] Appointment Type Filter changed to: $newFilter");
      if (mounted) {
        setState(() {
          _selectedAppointmentTypeFilter = newFilter;
        });
      }
      _setupRecordsStream();
    }
  }


  @override
  Widget build(BuildContext context) {
    debugPrint("[RecordsListScreen] Build method called. _isUserDataLoading: $_isUserDataLoading, _isSettingUpStream: $_isSettingUpStream");
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Records', style: TextStyle(color: Color(0xFF00695C))),
        backgroundColor: Colors.white,
        elevation: 1.0,
        automaticallyImplyLeading: false, // Assuming this is a tab screen
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Row(
              children: [
                Expanded(
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
                        onChanged: _onDateFilterChanged,
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
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedAppointmentTypeFilter,
                        icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                        elevation: 16,
                        style: TextStyle(color: Colors.grey[800], fontSize: 16),
                        onChanged: _onAppointmentTypeFilterChanged,
                        items: _appointmentTypeFilterOptions.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchUserDataAndSetupStream,
              color: Theme.of(context).primaryColor,
              child: Builder( // Use Builder to get a new context for LayoutBuilder if needed
                builder: (context) {
                  if (_isUserDataLoading) {
                    debugPrint("[RecordsListScreen] Build: Showing User Data Loading Indicator.");
                    return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))));
                  }
                  // Show loading indicator if stream is being set up AND _recordsStream is null
                  if (_isSettingUpStream && _recordsStream == null) {
                     debugPrint("[RecordsListScreen] Build: Showing Stream Setup Loading Indicator (_isSettingUpStream true, _recordsStream null).");
                     return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))));
                  }
                  // If stream is null but not actively setting up (e.g., initial state before first fetch completes or error)
                  if (_recordsStream == null && !_isSettingUpStream) {
                      debugPrint("[RecordsListScreen] Build: Records stream is null and not setting up. Showing 'No records to display'.");
                       return LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints viewportConstraints) {
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: viewportConstraints.maxHeight),
                              child: const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'No completed records to display. Pull down to refresh.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, color: Colors.grey)
                                  ),
                                )
                              ),
                            ),
                          );
                        }
                      );
                  }

                  return StreamBuilder<List<MedicalRecordSummary>>(
                    stream: _recordsStream,
                    builder: (context, snapshot) {
                      debugPrint("[RecordsListScreen] StreamBuilder rebuild. ConnectionState: ${snapshot.connectionState}, HasError: ${snapshot.hasError}, HasData: ${snapshot.hasData}");

                      if (snapshot.connectionState == ConnectionState.waiting && _isSettingUpStream) {
                        // Only show primary loading if _isSettingUpStream is true,
                        // otherwise, it might be just the stream waiting for new data after initial load.
                        debugPrint("[RecordsListScreen] StreamBuilder: Waiting for initial stream data because _isSettingUpStream is true.");
                        return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))));
                      }
                      if (snapshot.hasError) {
                        debugPrint("[RecordsListScreen] StreamBuilder error: ${snapshot.error}");
                        return Center(child: Text('Error loading records: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        debugPrint("[RecordsListScreen] StreamBuilder: No data or empty data for current filters.");
                        return LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints viewportConstraints) {
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: viewportConstraints.maxHeight),
                                child: const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'No completed records found for the selected filters.\nPull down to refresh.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16, color: Colors.grey)
                                    ),
                                  )
                                ),
                              ),
                            );
                          }
                        );
                      }

                      List<MedicalRecordSummary> records = snapshot.data!;
                      debugPrint("[RecordsListScreen] StreamBuilder: Displaying ${records.length} completed records.");
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          // Determine icon based on type (you'll need to add 'appointmentType' to MedicalRecordSummary if you want to use it here)
                          // For now, using a generic icon or logic based on specialty
                          IconData displayIcon = Icons.receipt_long_outlined; // Default
                          // if (record.appointmentType == 'video') {
                          //   displayIcon = Icons.videocam_outlined;
                          // } else if (record.doctorSpecialty.toLowerCase().contains('lab')) { // Example
                          //   displayIcon = Icons.science_outlined;
                          // }


                          return Card(
                            key: ValueKey(record.id), // Good for list performance
                            margin: const EdgeInsets.only(bottom: 12.0),
                            elevation: 2.0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(displayIcon, color: Theme.of(context).primaryColor, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "${record.doctorName} (${record.doctorSpecialty})",
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF00695C)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildRecordInfoRow('Date:', record.period),
                                  _buildRecordInfoRow('Patient Age (approx.):', record.patientAgeAtEvent ?? 'N/A'),
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
                  );
                },
              ),
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
