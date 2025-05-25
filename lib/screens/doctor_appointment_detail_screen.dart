// lib/screens/doctor_appointment_detail_screen.dart
import 'dart:io'; // For File type
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:file_picker/file_picker.dart'; // For picking files
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage; // For Firebase Storage

import '../models/doctor_model.dart'; // Ensure this path is correct

class DoctorAppointmentDetailScreen extends StatefulWidget {
  final Doctor doctor;
  final String? bookingType;

  const DoctorAppointmentDetailScreen({
    super.key,
    required this.doctor,
    this.bookingType = "in_person",
  });

  @override
  State<DoctorAppointmentDetailScreen> createState() =>
      _DoctorAppointmentDetailScreenState();
}

class _DoctorAppointmentDetailScreenState extends State<DoctorAppointmentDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _notesController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isLoadingSlots = false;
  bool _isBooking = false;
  String? _currentUserName;
  List<String> _availableTimeSlots = [];

  // State variables for PDF upload
  File? _selectedMedicalReport;
  String? _selectedReportFileName;
  // No need for _isUploadingReport separately, _isBooking can cover the overall process

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserName();
    _selectedDate = DateTime.now(); // Default to today, date picker will enforce future dates
    if (widget.doctor.uid.isNotEmpty) {
      _filterAvailableSlotsForSelectedDate();
    } else {
      debugPrint("[DoctorAppointmentDetailScreen] Error: Doctor UID is empty in initState.");
      if (mounted) {
        setState(() {
          _isLoadingSlots = false;
          _availableTimeSlots = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Doctor information is incomplete.')),
        );
      }
    }
  }

  Future<void> _fetchCurrentUserName() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (mounted) {
          setState(() {
            if (userDoc.exists && userDoc.data() != null) {
              final data = userDoc.data() as Map<String, dynamic>;
              _currentUserName = data['displayName'] ?? currentUser.displayName ?? 'User';
            } else {
              _currentUserName = currentUser.displayName ?? currentUser.email ?? 'User';
            }
          });
        }
      } catch (e) {
        debugPrint("[DoctorAppointmentDetailScreen] Error fetching current user's name: $e");
        if (mounted) {
          setState(() {
            _currentUserName = currentUser.displayName ?? currentUser.email ?? 'User'; // Fallback
          });
        }
      }
    } else {
      debugPrint("[DoctorAppointmentDetailScreen] Error: Current user is null in _fetchCurrentUserName.");
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(), // User can select today
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != _selectedDate) {
      if (mounted) {
        setState(() {
          _selectedDate = picked;
          _selectedTimeSlot = null;
          _availableTimeSlots = [];
        });
      }
      if (widget.doctor.uid.isNotEmpty) {
        _filterAvailableSlotsForSelectedDate();
      } else {
        debugPrint("[DoctorAppointmentDetailScreen] Error: Doctor UID is empty in _selectDate.");
      }
    }
  }

  Future<void> _filterAvailableSlotsForSelectedDate() async {
    if (_selectedDate == null) {
      debugPrint("[DoctorAppointmentDetailScreen] _filterAvailableSlotsForSelectedDate: _selectedDate is null.");
      return;
    }
    if (widget.doctor.uid.isEmpty) {
      debugPrint("[DoctorAppointmentDetailScreen] _filterAvailableSlotsForSelectedDate: Doctor UID is empty.");
      if (mounted) {
        setState(() => _isLoadingSlots = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot load slots: Doctor ID missing.')),
        );
      }
      return;
    }

    debugPrint("[DoctorAppointmentDetailScreen] Filtering slots for doctor: ${widget.doctor.uid} on date: $_selectedDate");

    if (mounted) {
      setState(() {
        _isLoadingSlots = true;
      });
    }

    try {
      String dayOfWeek = DateFormat('EEEE').format(_selectedDate!).toLowerCase();
      debugPrint("[DoctorAppointmentDetailScreen] Day of week: $dayOfWeek");

      DocumentSnapshot doctorDoc = await _firestore.collection('doctors').doc(widget.doctor.uid).get();
      debugPrint("[DoctorAppointmentDetailScreen] Fetched doctor document: ${doctorDoc.id}, Exists: ${doctorDoc.exists}");

      if (!doctorDoc.exists) {
        throw Exception('Doctor document not found for UID: ${widget.doctor.uid}');
      }

      Map<String, dynamic> doctorData = doctorDoc.data() as Map<String, dynamic>;
      debugPrint("[DoctorAppointmentDetailScreen] Doctor data: $doctorData");

      if (!doctorData.containsKey('availableSlots')) {
        debugPrint('[DoctorAppointmentDetailScreen] No availableSlots field found in doctor document');
        if (mounted) {
          setState(() {
            _availableTimeSlots = [];
            _isLoadingSlots = false;
          });
        }
        return;
      }

      var availableSlotsMap = doctorData['availableSlots'] as Map<String, dynamic>?;
      if (availableSlotsMap == null || !availableSlotsMap.containsKey(dayOfWeek) || availableSlotsMap[dayOfWeek] == null) {
        debugPrint('[DoctorAppointmentDetailScreen] No slots available for $dayOfWeek or slots data is null/missing.');
        if (mounted) {
          setState(() {
            _availableTimeSlots = [];
            _isLoadingSlots = false;
          });
        }
        return;
      }

      List<String> slots = List<String>.from(availableSlotsMap[dayOfWeek] as List<dynamic>? ?? []);
      debugPrint("[DoctorAppointmentDetailScreen] Initial slots for $dayOfWeek: $slots");

      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      debugPrint("[DoctorAppointmentDetailScreen] Querying appointments for doctor ${widget.doctor.uid} on $formattedDate");
      QuerySnapshot appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctor.uid)
          .where('appointmentDate', isEqualTo: formattedDate)
          .where('status', whereIn: ['booked', 'confirmed', 'video_link_added'])
          .get();
      debugPrint("[DoctorAppointmentDetailScreen] Found ${appointmentsSnapshot.docs.length} booked/confirmed appointments.");

      List<String> bookedSlots = appointmentsSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['appointmentTime'] as String)
          .toList();
      debugPrint("[DoctorAppointmentDetailScreen] Booked slots: $bookedSlots");

      slots.removeWhere((slot) => bookedSlots.contains(slot));
      debugPrint("[DoctorAppointmentDetailScreen] Final available slots: $slots");

      if (mounted) {
        setState(() {
          _availableTimeSlots = slots;
          _isLoadingSlots = false;
        });
      }
    } catch (e, s) {
      debugPrint('[DoctorAppointmentDetailScreen] Error filtering slots: $e');
      debugPrint('[DoctorAppointmentDetailScreen] Stacktrace: $s');
      if (mounted) {
        setState(() {
          _availableTimeSlots = [];
          _isLoadingSlots = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading time slots: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickMedicalReport() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        int fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) { // 5MB limit
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File is too large. Max 5MB allowed.')),
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _selectedMedicalReport = file;
            _selectedReportFileName = result.files.single.name;
          });
        }
      } else {
        if (mounted) {
          // User canceled the picker, do not show a snackbar unless it's an error.
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('No PDF file selected.')),
          // );
          debugPrint("File picking cancelled by user.");
        }
      }
    } catch (e) {
      debugPrint('Error picking medical report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _bookAppointment() async {
    if (_selectedTimeSlot == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time slot')),
      );
      return;
    }
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in. Please restart.')),
      );
      return;
    }
    if (_currentUserName == null) {
      await _fetchCurrentUserName();
      if (_currentUserName == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not fetch user details. Try again.')),
        );
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isBooking = true;
      });
    }

    String? reportUrl;
    String? reportFileNameForDb;
    SnackBar? uploadingSnackbar; // To manually dismiss later

    try {
      // --- Upload Medical Report if selected ---
      if (_selectedMedicalReport != null) {
        // Check if the file exists before attempting to upload
        if (!await _selectedMedicalReport!.exists()) {
          debugPrint("Selected medical report file does not exist at path: ${_selectedMedicalReport!.path}");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Selected report file not found. Please select again.')),
            );
            setState(() => _isBooking = false);
          }
          return;
        }

        reportFileNameForDb = _selectedReportFileName ?? 'medical_report.pdf';
        String filePath =
            'medical_reports/${currentUser.uid}/${widget.doctor.uid}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}/$reportFileNameForDb';
        
        firebase_storage.Reference ref =
            firebase_storage.FirebaseStorage.instance.ref().child(filePath);

        if (mounted) {
          // Show a persistent snackbar for uploading
          uploadingSnackbar = const SnackBar(
            duration: Duration(minutes: 5), // Long duration, will be dismissed manually
            content: Row(children: [CircularProgressIndicator(), SizedBox(width: 15), Text('Uploading report...')])
          );
          ScaffoldMessenger.of(context).showSnackBar(uploadingSnackbar);
        }

        firebase_storage.UploadTask uploadTask = ref.putFile(_selectedMedicalReport!);
        firebase_storage.TaskSnapshot snapshot = await uploadTask;
        reportUrl = await snapshot.ref.getDownloadURL();
        debugPrint('Report uploaded. URL: $reportUrl');
        
        if (mounted && uploadingSnackbar != null) {
           ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide uploading snackbar on success
        }
      }
      // --- End of Report Upload ---

      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      
      QuerySnapshot existingAppointments = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: currentUser.uid)
          .where('appointmentDate', isEqualTo: formattedDate)
          .where('appointmentTime', isEqualTo: _selectedTimeSlot)
          .where('status', whereIn: ['booked', 'confirmed', 'video_link_added'])
          .get();

      if (existingAppointments.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have an appointment scheduled for this time slot.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isBooking = false);
        }
        return;
      }
      
      String sanitizedTimeSlot = _selectedTimeSlot!.replaceAll(' ', '_').replaceAll(':', '_');
      String appointmentId = '${widget.doctor.uid}_${currentUser.uid}_${formattedDate}_$sanitizedTimeSlot';

      final timeComponents = DateFormat('hh:mm a').parse(_selectedTimeSlot!);
      final appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        timeComponents.hour,
        timeComponents.minute,
      );

      final String userName = _currentUserName!;

      final appointmentData = {
        'appointmentId': appointmentId,
        'userId': currentUser.uid,
        'userName': userName,
        'doctorId': widget.doctor.uid,
        'doctorName': widget.doctor.name,
        'doctorSpeciality': widget.doctor.specialization,
        'appointmentDate': formattedDate,
        'appointmentTime': _selectedTimeSlot!,
        'dateTimeFull': Timestamp.fromDate(appointmentDateTime.toUtc()),
        'category': widget.doctor.specialization,
        'status': 'booked',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'appointmentType': widget.bookingType ?? 'in_person',
        'videoConsultationLink': null,
        'isVideoLinkShared': false,
        'diagnosis': null,
        'medicalReportUrl': reportUrl, 
        'medicalReportFileName': reportFileNameForDb,
      };
      debugPrint("[DoctorAppointmentDetailScreen] Attempting to create appointment with data: $appointmentData");

      await _firestore.collection('appointments').doc(appointmentId).set(appointmentData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Appointment booked ${reportUrl != null ? "and report uploaded " : ""}successfully!')),
        );
        Navigator.pop(context, true); 
      }
    } catch (e, s) {
      debugPrint('[DoctorAppointmentDetailScreen] Error booking appointment or uploading report: $e');
      debugPrint('[DoctorAppointmentDetailScreen] Stacktrace: $s');
      if (mounted) {
        if (uploadingSnackbar != null) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide uploading snackbar on error
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to book appointment/upload report: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Doctor doctor = widget.doctor;
    String qualificationsText = (doctor.qualifications != null && doctor.qualifications!.isNotEmpty)
        ? doctor.qualifications!.join(', ')
        : 'Not specified';

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.bookingType == "video"
                ? "Video Consult: ${doctor.name}"
                : doctor.name,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6EB6B4),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor Info Card (existing)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: doctor.imageUrl != null && doctor.imageUrl!.isNotEmpty
                          ? NetworkImage(doctor.imageUrl!)
                          : null,
                      child: doctor.imageUrl == null || doctor.imageUrl!.isEmpty
                          ? Icon(Icons.person, size: 40, color: Theme.of(context).primaryColor)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doctor.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(doctor.specialization, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                          if (qualificationsText != 'Not specified')
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(qualificationsText, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                            ),
                          if (doctor.yearsOfExperience != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text('${doctor.yearsOfExperience} years experience', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                            ),
                          if (doctor.consultationFee != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text('Fee: ₹${doctor.consultationFee?.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, color: Colors.teal, fontWeight: FontWeight.w500)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (doctor.bio != null && doctor.bio!.isNotEmpty) ...[
              const Text('About Doctor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(doctor.bio!, style: const TextStyle(fontSize: 15, height: 1.4)),
              const SizedBox(height: 20),
            ],

            // Select Date (existing)
            const Text('Select Date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDate == null
                          ? 'Tap to select a date'
                          : DateFormat('EEE, dd MMM, yyyy').format(_selectedDate!), // Corrected format
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.teal),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Select Time Slot (existing)
            const Text('Select Time Slot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _isLoadingSlots
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))),
                  ))
                : _availableTimeSlots.isEmpty
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                            _selectedDate == null ? 'Please select a date first.' : 'No slots available for this date.',
                            style: const TextStyle(color: Colors.grey, fontSize: 15)),
                      ))
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _availableTimeSlots.length,
                        itemBuilder: (context, index) {
                          final slot = _availableTimeSlots[index];
                          final isSelected = slot == _selectedTimeSlot;
                          return ElevatedButton(
                            onPressed: () {
                              if (mounted) setState(() => _selectedTimeSlot = slot);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected ? Colors.teal : Colors.grey.shade200,
                              foregroundColor: isSelected ? Colors.white : Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: isSelected ? 2 : 0,
                            ),
                            child: Text(slot),
                          );
                        },
                      ),
            const SizedBox(height: 20),

            // --- New UI for PDF Upload ---
            const Text('Upload Medical Report (PDF only, Optional)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.attach_file_outlined),
              label: Text(_selectedMedicalReport == null ? 'Select Report (PDF)' : 'Change Report'),
              onPressed: _isBooking ? null : _pickMedicalReport, 
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (_selectedMedicalReport != null)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Selected: $_selectedReportFileName',
                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_isBooking) 
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                        tooltip: 'Remove selected report',
                        onPressed: () {
                          setState(() {
                            _selectedMedicalReport = null;
                            _selectedReportFileName = null;
                          });
                        },
                      )
                  ],
                ),
              ),
            // --- End of PDF Upload UI ---

            const SizedBox(height: 20),
            const Text('Notes (Optional)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Any specific information for the doctor...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isBooking || _selectedDate == null || _selectedTimeSlot == null) ? null : _bookAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isBooking
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 22, width: 22, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                          ),
                          SizedBox(width: 12),
                          Text('Booking...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        ],
                      )
                    : const Text('Confirm Appointment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
