import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class Doctor {
  final String uid;
  final String name;
  final String specialization;

  Doctor({required this.uid, required this.name, required this.specialization});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Doctor && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() {
    return '$name ($specialization)';
  }
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Doctor> _doctors = [];
  Doctor? _selectedDoctor;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  bool _isLoadingDoctors = true;
  bool _isBooking = false;

  User? _currentUser;
  Map<String, dynamic>? _currentUserData;


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
      _fetchDoctors();
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
        }
      } catch (e) {
        debugPrint("Error fetching current user details: $e");
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load your details: ${e.toString()}')),
          );
        }
      }
    }
  }


  Future<void> _fetchDoctors() async {
    if(!mounted) return;
    setState(() {
      _isLoadingDoctors = true;
    });
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .where('isActive', isEqualTo: true)
          .get();

      List<Doctor> fetchedDoctors = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Doctor(
          uid: doc.id,
          name: data['displayName'] ?? data['fullName'] ?? 'N/A',
          specialization: data['specialization'] ?? 'General Physician',
        );
      }).toList();

      if (mounted) {
        setState(() {
          _doctors = fetchedDoctors;
          _isLoadingDoctors = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDoctors = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load doctors: ${e.toString()}')),
        );
      }
      debugPrint("Error fetching doctors: $e");
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
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF008080),
              ),
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
        });
      }
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
       builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
             colorScheme: const ColorScheme.light(
              primary: Color(0xFF008080),
              onPrimary: Colors.white,
              onSurface: Colors.black,
              surface: Colors.white,
            ),
            timePickerTheme: TimePickerThemeData(
              dialHandColor: const Color(0xFF008080),
              hourMinuteTextColor: WidgetStateColor.resolveWith((Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return Colors.black54;
              }),
              hourMinuteColor: WidgetStateColor.resolveWith((Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF008080);
                }
                return Colors.grey.shade200;
              }),
              dayPeriodTextColor: WidgetStateColor.resolveWith((Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return const Color(0xFF008080);
              }),
              dayPeriodColor: WidgetStateColor.resolveWith((Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF008080);
                }
                return Colors.grey.shade200;
              }),
               helpTextStyle: const TextStyle(color: Color(0xFF008080)),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF008080),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
       if (mounted) {
        setState(() {
          _selectedTime = picked;
          _timeController.text = picked.format(context);
        });
      }
    }
  }

  Future<void> _confirmAndBookAppointment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentUser == null || _currentUserData == null) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User information not available. Please try logging in again.')),
        );
       }
      return;
    }

    setState(() {
      _isBooking = true;
    });

    try {
      final DateTime finalDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      if (finalDateTime.isBefore(DateTime.now())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot book appointments in the past.')),
          );
          setState(() => _isBooking = false);
        }
        return;
      }

      await _firestore.collection('appointments').add({
        'patientUid': _currentUser!.uid,
        'patientName': _currentUserData!['displayName'] ?? _currentUserData!['fullName'] ?? 'N/A',
        'doctorId': _selectedDoctor!.uid,
        'doctorName': _selectedDoctor!.name,
        'doctorSpecialization': _selectedDoctor!.specialization,
        'dateTime': Timestamp.fromDate(finalDateTime),
        'reasonForVisit': _reasonController.text.trim().isEmpty ? 'Not specified' : _reasonController.text.trim(),
        'status': 'scheduled',
        'createdAt': Timestamp.now(),
        'appointmentType': 'consultation',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
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
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book an Appointment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6EB6B4),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoadingDoctors
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))))
          : _doctors.isEmpty && !_isLoadingDoctors
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No doctors available for booking at the moment. Please check back later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Choose Your Doctor and Time',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00695C),
                          ),
                        ),
                        const SizedBox(height: 24),

                        DropdownButtonFormField<Doctor>(
                          decoration: InputDecoration(
                            labelText: 'Select Doctor',
                            prefixIcon: const Icon(Icons.medical_services_outlined, color: Color(0xFF008080)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                             focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFF008080), width: 2.0)
                              ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                          ),
                          value: _selectedDoctor,
                          isExpanded: true,
                          items: _doctors.map((Doctor doctor) {
                            return DropdownMenuItem<Doctor>(
                              value: doctor,
                              child: Text(doctor.toString()),
                            );
                          }).toList(),
                          onChanged: (Doctor? newValue) {
                            setState(() {
                              _selectedDoctor = newValue;
                            });
                          },
                          validator: (value) => value == null ? 'Please select a doctor' : null,
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Select Date',
                            hintText: 'Tap to choose appointment date',
                            prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF008080)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                             focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFF008080), width: 2.0)
                              ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                          ),
                          onTap: () => _selectDate(context),
                          validator: (value) => value == null || value.isEmpty ? 'Please select a date' : null,
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _timeController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Select Time',
                            hintText: 'Tap to choose appointment time',
                            prefixIcon: const Icon(Icons.access_time_outlined, color: Color(0xFF008080)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFF008080), width: 2.0)
                              ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                          ),
                          onTap: () => _selectTime(context),
                          validator: (value) => value == null || value.isEmpty ? 'Please select a time' : null,
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _reasonController,
                          decoration: InputDecoration(
                            labelText: 'Reason for Visit (Optional)',
                            hintText: 'e.g., Regular check-up, fever',
                            prefixIcon: const Icon(Icons.notes_outlined, color: Color(0xFF008080)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFF008080), width: 2.0)
                              ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                          ),
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 30),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008080),
                            padding: const EdgeInsets.symmetric(vertical: 16.0), // Applied const
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), // Applied const
                          ),
                          onPressed: _isBooking ? null : _confirmAndBookAppointment,
                          child: _isBooking
                              ? const SizedBox( // Applied const
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator( // Applied const
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text( // Applied const
                                  'Confirm Booking',
                                  style: TextStyle(color: Colors.white) // Applied const
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}