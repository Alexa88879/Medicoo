// lib/screens/select_doctor_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doctor_appointment_detail_screen.dart';
import '../models/doctor_model.dart';

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
          .where('speciality', isEqualTo: specialization) // Ensure field name matches Firestore
          .where('isAvailable', isEqualTo: true); // Ensure field name matches Firestore

      // Filter for video consultation capable doctors if bookingType is "video"
      // Make sure 'offersVideoConsultation' field exists in your Firestore 'doctors' documents.
      if (bookingType == "video") {
        query = query.where('offersVideoConsultation', isEqualTo: true);
      }

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
        backgroundColor: const Color(0xFF6EB6B4), // Teal color
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
                  style: const TextStyle(color: Colors.red, fontSize: 16),
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
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              String qualificationsText = (doctor.qualifications != null && doctor.qualifications!.isNotEmpty)
                                          ? doctor.qualifications!.join(', ')
                                          : 'Qualifications not specified';
              String experienceText = doctor.yearsOfExperience != null
                                          ? '${doctor.yearsOfExperience} years experience'
                                          : 'Experience not specified';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                elevation: 3.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                child: InkWell( // Added InkWell for better tap feedback
                  borderRadius: BorderRadius.circular(12.0),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorAppointmentDetailScreen(
                          doctor: doctor,
                          bookingType: widget.bookingType,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: doctor.imageUrl != null && doctor.imageUrl!.isNotEmpty
                              ? NetworkImage(doctor.imageUrl!)
                              : null,
                          child: doctor.imageUrl == null || doctor.imageUrl!.isEmpty
                              ? Icon(Icons.person_outline, size: 35, color: Theme.of(context).primaryColor)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(doctor.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF004D40))),
                              const SizedBox(height: 4),
                              Text(doctor.specialization, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                              const SizedBox(height: 2),
                              Text(qualificationsText, style: TextStyle(fontSize: 13, color: Colors.grey[600]), overflow: TextOverflow.ellipsis, maxLines: 1),
                               const SizedBox(height: 2),
                              Text(experienceText, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
