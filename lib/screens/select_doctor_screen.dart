//lib\screens\select_doctor_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doctor_appointment_detail_screen.dart';
import '../models/doctor_model.dart';
import 'book_video_consultation_screen.dart'; // Import the new screen

class SelectDoctorScreen extends StatefulWidget {
  final String specialization;
  final String? bookingType; // "in_person" or "video"

  const SelectDoctorScreen({
    super.key,
    required this.specialization,
    this.bookingType = "in_person", // Default to in_person
  });

  @override
  State<SelectDoctorScreen> createState() => _SelectDoctorScreenState();
}

class _SelectDoctorScreenState extends State<SelectDoctorScreen> {
  late Future<List<Doctor>> _doctorsFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _doctorsFuture = _fetchDoctorsBySpecialization(widget.specialization, widget.bookingType);
  }

  Future<List<Doctor>> _fetchDoctorsBySpecialization(String specialization, String? bookingType) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('doctors')
          .where('speciality', isEqualTo: specialization)
          .where('isAvailable', isEqualTo: true);

      // If booking type is video, filter for doctors offering video consultations
      if (bookingType == "video") {
        // Assuming 'offersVideoConsultation' is a boolean field in your 'doctors' collection
        // If this field doesn't exist, this query might return no doctors for "video" type.
        // Ensure your Firestore data for doctors includes this field.
        query = query.where('offersVideoConsultation', isEqualTo: true);
      }
      // You might want to add .orderBy() here if needed, e.g., .orderBy('rating', descending: true)
      // For example: query = query.orderBy('name');

      QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();


      if (snapshot.docs.isEmpty) {
        debugPrint('No doctors found for specialization "$specialization" and bookingType "$bookingType"');
        return [];
      }

      return snapshot.docs.map((doc) => Doctor.fromFirestore(doc)).toList();

    } catch (e) {
      debugPrint("Error fetching doctors by specialization: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load doctors: ${e.toString()}')),
        );
      }
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = widget.bookingType == "video"
        ? 'Video Consultation: Select Doctor'
        : 'Doctors for ${widget.specialization}';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6EB6B4),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: FutureBuilder<List<Doctor>>(
        future: _doctorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Could not load doctors. Please try again later.\nError: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            String message = widget.bookingType == "video"
                ? 'No doctors found offering video consultations for ${widget.specialization} at the moment.'
                : 'No doctors found for ${widget.specialization} at the moment.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          List<Doctor> doctors = snapshot.data!;
          return ListView.builder(
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              String qualificationsText = (doctor.qualifications != null && doctor.qualifications!.isNotEmpty)
                                          ? doctor.qualifications!.join(', ')
                                          : 'Not specified';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                elevation: 2.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: doctor.imageUrl != null && doctor.imageUrl!.isNotEmpty
                        ? NetworkImage(doctor.imageUrl!)
                        : null,
                    child: doctor.imageUrl == null || doctor.imageUrl!.isEmpty
                        ? Icon(Icons.person, size: 30, color: Theme.of(context).primaryColor)
                        : null,
                  ),
                  title: Text(doctor.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${doctor.specialization}\n$qualificationsText'),
                  isThreeLine: qualificationsText != 'Not specified' && qualificationsText.isNotEmpty,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    if (widget.bookingType == "video") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookVideoConsultationScreen(doctor: doctor),
                        ),
                      );
                    } else { // Default to in-person or existing flow
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorAppointmentDetailScreen(doctor: doctor),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
