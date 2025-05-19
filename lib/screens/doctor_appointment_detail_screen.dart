// lib/screens/doctor_appointment_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../models/doctor_model.dart'; // Ensure this path is correct

class DoctorAppointmentDetailScreen extends StatefulWidget {
  final Doctor doctor;

  const DoctorAppointmentDetailScreen({super.key, required this.doctor});

  @override
  State<DoctorAppointmentDetailScreen> createState() =>
      _DoctorAppointmentDetailScreenState();
}

class _DoctorAppointmentDetailScreenState
    extends State<DoctorAppointmentDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isLoading = false; // General loading state for the screen or specific parts
  bool _isBooking = false; // Specific loading state for the booking process
  String? _currentUserName;

  // Example static time slots as per PDF - can be made dynamic later
  final List<String> _timeSlots = [
    '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM',
    '11:00 AM', '11:30 AM', '12:00 PM', '12:30 PM',
    '01:00 PM', '01:30 PM', '02:00 PM', '02:30 PM',
    '03:00 PM', '03:30 PM', '04:00 PM', '04:30 PM',
    '05:00 PM'
  ];

  List<String> _availableTimeSlots = [];

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserName();
    _selectedDate = DateTime.now(); // Default to today
    _filterAvailableSlotsForSelectedDate(); // Initial filter
  }

  Future<void> _fetchCurrentUserName() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (mounted) { // Check mounted before setState
          setState(() {
            if (userDoc.exists && userDoc.data() != null) {
              _currentUserName = (userDoc.data() as Map<String, dynamic>)['displayName'] ?? currentUser.displayName ?? 'User';
            } else {
              _currentUserName = currentUser.displayName ?? currentUser.email ?? 'User';
            }
          });
        }
      } catch (e) {
        debugPrint("Error fetching current user's name: $e");
         if (mounted) { // Check mounted before setState
            setState(() {
              _currentUserName = currentUser.displayName ?? currentUser.email ?? 'User'; // Fallback
            });
         }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(), 
      lastDate: DateTime.now().add(const Duration(days: 90)), 
    );
    if (picked != null && picked != _selectedDate) {
      if (mounted) { // Check mounted before setState
        setState(() {
          _selectedDate = picked;
          _selectedTimeSlot = null; 
        });
      }
      _filterAvailableSlotsForSelectedDate();
    }
  }
  
  Future<void> _filterAvailableSlotsForSelectedDate() async {
    if (_selectedDate == null) {
      if (mounted) setState(() => _availableTimeSlots = []);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    List<String> generalDaySlots = [];
    if (widget.doctor.availableSlots != null) {
      String dayOfWeek = DateFormat('EEEE').format(_selectedDate!).toLowerCase(); 
      generalDaySlots = widget.doctor.availableSlots![dayOfWeek] ?? _timeSlots; 
    } else {
      generalDaySlots = List.from(_timeSlots); 
    }
    
    try {
      final String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      QuerySnapshot bookedSlotsSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctor.uid)
          .where('appointmentDate', isEqualTo: formattedDate)
          .where('status', whereIn: ['booked', 'confirmed']) 
          .get();

      List<String> bookedTimes = bookedSlotsSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['appointmentTime'] as String)
          .toList();
      
      if (mounted) {
        setState(() {
          _availableTimeSlots = generalDaySlots.where((slot) => !bookedTimes.contains(slot)).toList();
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint("Error fetching booked slots: $e");
      if (mounted) { // Guard context access
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading available slots: ${e.toString()}')),
        );
        setState(() {
          _availableTimeSlots = List.from(generalDaySlots); 
          _isLoading = false;
        });
      }
    }
  }


  Future<void> _bookAppointment() async {
    if (_selectedDate == null || _selectedTimeSlot == null) {
      if (mounted) { // Guard context access
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date and time slot.')),
        );
      }
      return;
    }

    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) { // Guard context access
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to be logged in to book.')),
        );
      }
      return;
    }
     if (_currentUserName == null) {
      if (mounted) { // Guard context access
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fetching user details, please wait...')),
        );
      }
      await _fetchCurrentUserName(); 
      if(_currentUserName == null) { // Re-check after attempting to fetch
         if (mounted) { // Guard context access
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not fetch user details. Please try again.')),
            );
         }
        return;
      }
    }

    if (mounted) setState(() => _isBooking = true); // Use _isBooking for the button loader

    try {
      final String datePart = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final timeParts = _selectedTimeSlot!.split(' '); 
      final hourMinute = timeParts[0].split(':'); 
      int hour = int.parse(hourMinute[0]);
      final int minute = int.parse(hourMinute[1]);

      if (timeParts[1].toUpperCase() == 'PM' && hour != 12) {
        hour += 12;
      } else if (timeParts[1].toUpperCase() == 'AM' && hour == 12) { 
        hour = 0;
      }

      final DateTime fullDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        hour,
        minute,
      );
      final Timestamp appointmentTimestamp = Timestamp.fromDate(fullDateTime);

      QuerySnapshot existingAppointments = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctor.uid)
          .where('dateTimeFull', isEqualTo: appointmentTimestamp)
          .where('status', whereIn: ['booked', 'confirmed'])
          .limit(1)
          .get();

      if (existingAppointments.docs.isNotEmpty) {
        if (mounted) { // Guard context access
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This slot was just booked. Please select another.')),
          );
        }
        _filterAvailableSlotsForSelectedDate(); 
        if (mounted) setState(() => _isBooking = false);
        return;
      }

      DocumentReference appointmentRef = _firestore.collection('appointments').doc();
      await appointmentRef.set({
        'appointmentId': appointmentRef.id, 
        'userId': currentUser.uid,
        'userName': _currentUserName, 
        'doctorId': widget.doctor.uid,
        'doctorName': widget.doctor.name,
        'doctorSpeciality': widget.doctor.specialization,
        'appointmentDate': datePart, 
        'appointmentTime': _selectedTimeSlot,
        'dateTimeFull': appointmentTimestamp, 
        'category': widget.doctor.specialization, 
        'status': 'booked', 
        'createdAt': FieldValue.serverTimestamp(),
        'notes': '', 
      });

      if (mounted) { // Guard context access
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment booked successfully!')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst); 
      }
    } catch (e) {
      debugPrint("Error booking appointment: $e");
      if (mounted) { // Guard context access
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to book appointment: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Doctor doctor = widget.doctor;
    String qualificationsText = (doctor.qualifications != null && doctor.qualifications!.isNotEmpty)
        ? doctor.qualifications!.join(', ')
        : 'Not specified';

    return Scaffold(
      appBar: AppBar(
        title: Text(doctor.name, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6EB6B4),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                          Text(doctor.specialization, style: TextStyle(fontSize: 16, color: Colors.grey[700])), // Corrected
                          if (qualificationsText != 'Not specified')
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(qualificationsText, style: TextStyle(fontSize: 14, color: Colors.grey[600])), // Corrected
                            ),
                          if (doctor.yearsOfExperience != null)
                             Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text('${doctor.yearsOfExperience} years experience', style: TextStyle(fontSize: 14, color: Colors.grey[600])), // Corrected
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
            if(doctor.bio != null && doctor.bio!.isNotEmpty) ...[
              const Text('About Doctor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(doctor.bio!, style: const TextStyle(fontSize: 15, height: 1.4)),
              const SizedBox(height: 20),
            ],

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

            const Text('Select Time Slot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _isLoading // General loading for slots
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))),
                  ))
                : _availableTimeSlots.isEmpty
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _selectedDate == null ? 'Please select a date first.' : 'No slots available for this date.',
                           style: const TextStyle(color: Colors.grey, fontSize: 15)
                        ),
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
                child: _isBooking // Use _isBooking for the button's loading state
                    ? const CircularProgressIndicator(color: Colors.white)
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
