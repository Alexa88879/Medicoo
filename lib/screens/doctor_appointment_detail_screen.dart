import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/doctor_model.dart'; // Ensure this path is correct

class DoctorAppointmentDetailScreen extends StatefulWidget {
  final Doctor doctor;

  const DoctorAppointmentDetailScreen({super.key, required this.doctor});

  @override
  State<DoctorAppointmentDetailScreen> createState() => _DoctorAppointmentDetailScreenState();
}

class _DoctorAppointmentDetailScreenState extends State<DoctorAppointmentDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  final TextEditingController _dateController = TextEditingController();
  // final TextEditingController _reasonController = TextEditingController(); // Uncomment if you add reason field

  bool _isBooking = false;
  User? _currentUser;
  Map<String, dynamic>? _currentUserData;

  final List<String> _timeSlots = [
    '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM',
    '12:00 PM', '12:30 PM', '01:00 PM', '01:30 PM', '02:00 PM', '02:30 PM',
    '03:00 PM', '03:30 PM', '04:00 PM', '04:30 PM', '05:00 PM'
  ];

  List<String> _bookedTimeSlots = [];
  bool _isLoadingTimeSlots = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You need to be logged in.')),
          );
        }
      });
    } else {
      _fetchCurrentUserDetails();
    }
  }

  Future<void> _fetchCurrentUserDetails() async {
    if (_currentUser != null) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
        if (userDoc.exists && mounted) {
          setState(() {
            _currentUserData = userDoc.data() as Map<String, dynamic>?;
          });
        } else if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find your user details.')),
          );
        }
      } catch (e) {
        debugPrint("Error fetching current user details: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading your details: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _fetchBookedTimeSlots(DateTime date) async {
    if (!mounted) return;
    setState(() {
      _isLoadingTimeSlots = true;
      _bookedTimeSlots = []; 
    });

    try {
      DateTime startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
      DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      QuerySnapshot snapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctor.uid)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('status', whereIn: ['scheduled', 'confirmed'])
          .get();

      if (mounted) {
        setState(() {
          _bookedTimeSlots = snapshot.docs
              .map((doc) => doc['timeSlot'] as String?)
              .where((slot) => slot != null)
              .cast<String>()
              .toList();
          _isLoadingTimeSlots = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTimeSlots = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching booked slots: ${e.toString()}')),
        );
      }
      debugPrint("Error fetching booked slots: $e");
    }
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF008080),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF008080)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      if (mounted) {
        setState(() {
          _selectedDate = picked;
          _dateController.text = DateFormat('EEE, dd MMM, yyyy').format(picked);
          _selectedTimeSlot = null; 
        });
        _fetchBookedTimeSlots(picked); 
      }
    }
  }
  
  TimeOfDay _parseTimeSlot(String timeSlot) {
    final format = DateFormat("hh:mm a");
    final dt = format.parse(timeSlot);
    return TimeOfDay.fromDateTime(dt);
  }

  Future<void> _confirmAndBookAppointment() async {
    if (_selectedDate == null || _selectedTimeSlot == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date and a time slot.')),
        );
      }
      return;
    }
    if (_currentUser == null || _currentUserData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User information not available. Please log in again.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() { _isBooking = true; });
    }

    try {
      TimeOfDay parsedTime = _parseTimeSlot(_selectedTimeSlot!);
      DateTime finalDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      if (finalDateTime.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot book appointments in the past.')),
          );
          setState(() => _isBooking = false);
        }
        return;
      }

      // Match the required fields from the security rules
      await _firestore.collection('appointments').add({
        'patientUid': _currentUser!.uid,
        'patientName': _currentUserData!['displayName'] ?? _currentUserData!['fullName'] ?? 'N/A',
        'doctorId': widget.doctor.uid,
        'doctorName': widget.doctor.name,
        'doctorSpecialization': widget.doctor.specialization,
        'dateTime': Timestamp.fromDate(finalDateTime),
        'timeSlot': _selectedTimeSlot,
        'status': 'scheduled',
        'createdAt': Timestamp.now(),
        'appointmentType': 'consultation',
        // Add any missing required fields from security rules
        'reasonForVisit': 'Not specified' // Adding this as it's mentioned in the rules
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment booked successfully!'), backgroundColor: Colors.green),
        );
        int count = 0;
        Navigator.of(context).popUntil((_) => count++ >= 2); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to book appointment: ${e.toString()}')),
        );
      }
      debugPrint("Error booking appointment: $e");
    } finally {
      if (mounted) {
        setState(() { _isBooking = false; });
      }
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    // _reasonController.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String qualificationsText = (widget.doctor.qualifications != null && widget.doctor.qualifications!.isNotEmpty)
                                ? widget.doctor.qualifications!.join(', ')
                                : 'Not specified';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6EB6B4),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: widget.doctor.profilePictureUrl != null && widget.doctor.profilePictureUrl!.isNotEmpty
                      ? NetworkImage(widget.doctor.profilePictureUrl!)
                      : null,
                  child: widget.doctor.profilePictureUrl == null || widget.doctor.profilePictureUrl!.isEmpty
                      ? Icon(Icons.person, size: 40, color: Theme.of(context).primaryColor)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.doctor.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                      Text(widget.doctor.specialization, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                      Text(qualificationsText, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Select Date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF00695C))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'DD MMMM yyyy',
                    suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF008080)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    filled: true,
                    fillColor: Colors.grey[100],
                     contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                  ),
                   validator: (value) => value == null || value.isEmpty ? 'Please select a date' : null,
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text('Select Time Slot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF00695C))),
            const SizedBox(height: 12),
            if (_selectedDate == null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text('Please select a date first to see available time slots.', style: TextStyle(color: Colors.grey[600]))
                )
            else if (_isLoadingTimeSlots)
              const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)))))
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _timeSlots.map((slot) {
                  bool isSelected = _selectedTimeSlot == slot;
                  bool isBooked = _bookedTimeSlots.contains(slot);

                  return ChoiceChip(
                    label: Text(slot),
                    selected: isSelected,
                    selectedColor: const Color(0xFF008080),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isBooked ? Colors.grey.shade500 : Colors.black87),
                      decoration: isBooked ? TextDecoration.lineThrough : null,
                    ),
                    backgroundColor: isBooked ? Colors.grey.shade300 : Colors.grey.shade100,
                    disabledColor: Colors.grey.shade300, // For booked slots
                    onSelected: isBooked ? null : (selected) {
                      setState(() {
                        _selectedTimeSlot = selected ? slot : null;
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008080),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                onPressed: _isBooking ? null : _confirmAndBookAppointment,
                child: _isBooking
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('Confirm'),
              ),
            ),
             const SizedBox(height: 20), // Extra space at the bottom
          ],
        ),
      ),
    );
  }
}