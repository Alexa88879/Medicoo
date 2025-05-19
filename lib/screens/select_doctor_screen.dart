//lib\screens\select_doctor_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doctor_appointment_detail_screen.dart'; 
import '../models/doctor_model.dart'; // Ensure this path is correct and doctor_model.dart is updated

class SelectDoctorScreen extends StatefulWidget {
  final String specialization; // This should match the 'speciality' field in Firestore
  const SelectDoctorScreen({super.key, required this.specialization});

  @override
  State<SelectDoctorScreen> createState() => _SelectDoctorScreenState();
}

class _SelectDoctorScreenState extends State<SelectDoctorScreen> {
  late Future<List<Doctor>> _doctorsFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _doctorsFuture = _fetchDoctorsBySpecialization(widget.specialization);
  }

  Future<List<Doctor>> _fetchDoctorsBySpecialization(String specialization) async {
    try {
      // Fetching documents as Map<String, dynamic>
      QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('doctors') 
          .where('speciality', isEqualTo: specialization) // Querying by 'speciality'
          .where('isAvailable', isEqualTo: true) // Querying by 'isAvailable'
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      // Use the factory constructor from the Doctor model for mapping
      // This ensures that field names and types are handled as defined in the model
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctors for ${widget.specialization}', style: const TextStyle(color: Colors.white)),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No doctors found for ${widget.specialization} at the moment.',
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
              // Qualifications are List<String>? directly from the model via fromFirestore factory
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
                    // Use doctor.imageUrl from the model
                    backgroundImage: doctor.imageUrl != null && doctor.imageUrl!.isNotEmpty
                        ? NetworkImage(doctor.imageUrl!) // Accessing doctor.imageUrl
                        : null,
                    child: doctor.imageUrl == null || doctor.imageUrl!.isEmpty // Accessing doctor.imageUrl
                        ? Icon(Icons.person, size: 30, color: Theme.of(context).primaryColor)
                        : null,
                  ),
                  // Use doctor.name and doctor.specialization from the model
                  title: Text(doctor.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${doctor.specialization}\n$qualificationsText'),
                  isThreeLine: qualificationsText != 'Not specified' && qualificationsText.isNotEmpty,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // The Doctor object passed here now contains all fetched fields
                        // as mapped by Doctor.fromFirestore
                        builder: (context) => DoctorAppointmentDetailScreen(doctor: doctor),
                      ),
                    );
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
