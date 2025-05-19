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

class _DoctorAppointmentDetailScreenState extends State<DoctorAppointmentDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _notesController = TextEditingController();  // Add this line

  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isLoading = false;
  bool _isBooking = false;
  String? _currentUserName;
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
    if (mounted) {
      setState(() {
        _isLoading = true;  // Changed from _isLoadingSlots to _isLoading
      });
    }
    
    try {
      String dayOfWeek = DateFormat('EEEE').format(_selectedDate!).toLowerCase();
      
      DocumentSnapshot doctorDoc = await _firestore.collection('doctors').doc(widget.doctor.uid).get();
      
      if (!doctorDoc.exists) {
        throw Exception('Doctor document not found');
      }

      Map<String, dynamic> doctorData = doctorDoc.data() as Map<String, dynamic>;
      
      // Improved error handling and type checking
      if (!doctorData.containsKey('availableSlots')) {
        debugPrint('No availableSlots field found in doctor document');
        if (mounted) {
          setState(() {
            _availableTimeSlots = [];
            _isLoading = false;
          });
        }
        return;
      }

      var availableSlots = doctorData['availableSlots'];
      if (availableSlots == null || !availableSlots.containsKey(dayOfWeek)) {
        debugPrint('No slots available for $dayOfWeek');
        if (mounted) {
          setState(() {
            _availableTimeSlots = [];
            _isLoading = false;
          });
        }
        return;
      }

      // Properly handle the data type conversion
      List<String> slots = List<String>.from(availableSlots[dayOfWeek] ?? []);
      
      // Get booked appointments
      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      QuerySnapshot appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctor.uid)
          .where('appointmentDate', isEqualTo: formattedDate)
          .where('status', isEqualTo: 'booked')
          .get();
          
      List<String> bookedSlots = appointmentsSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['appointmentTime'] as String)
          .toList();
          
      slots.removeWhere((slot) => bookedSlots.contains(slot));
      
      if (mounted) {
        setState(() {
          _availableTimeSlots = slots;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error filtering slots: $e');
      if (mounted) {
        setState(() {
          _availableTimeSlots = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading time slots: ${e.toString()}')),
        );
      }
    }
  }


  Future<void> _bookAppointment() async {
    if (_selectedTimeSlot == null || _selectedDate == null) {  // Changed from _selectedSlot to _selectedTimeSlot
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time slot')),
      );
      return;
    }

    try {
      setState(() {
        _isBooking = true;
      });

      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      
      // Check for existing appointments at the same time
      QuerySnapshot existingAppointments = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('appointmentDate', isEqualTo: formattedDate)
          .where('appointmentTime', isEqualTo: _selectedTimeSlot)
          .where('status', isEqualTo: 'booked')
          .get();

      if (existingAppointments.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have an appointment scheduled for this time slot'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isBooking = false;
          });
        }
        return;
      }

      // Create appointment ID with sanitized time slot
      String sanitizedTimeSlot = _selectedTimeSlot!.replaceAll(' ', '_').replaceAll(':', '_');
      String appointmentId = '${widget.doctor.uid}_${_auth.currentUser!.uid}_${formattedDate}_$sanitizedTimeSlot';

      // Convert time slot to DateTime
      final timeComponents = DateFormat('hh:mm a').parse(_selectedTimeSlot!);
      final appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        timeComponents.hour,
        timeComponents.minute,
      ).toUtc(); // Convert to UTC

      // Ensure we have a valid user name
      final String userName = _currentUserName ?? 'Unknown User';

      // Create appointment with exact field structure matching security rules
      final appointmentData = {
        'appointmentId': appointmentId,
        'userId': _auth.currentUser!.uid,
        'userName': userName,
        'doctorId': widget.doctor.uid,
        'doctorName': widget.doctor.name,
        'doctorSpeciality': widget.doctor.specialization,
        'appointmentDate': formattedDate,
        'appointmentTime': _selectedTimeSlot!,
        'dateTimeFull': appointmentDateTime, // UTC DateTime
        'category': widget.doctor.specialization,
        'status': 'booked',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'notes': _notesController.text.trim(),
      };

      await _firestore.collection('appointments').doc(appointmentId).set(appointmentData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment booked successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error booking appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to book appointment: ${e.toString()}')),
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

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
