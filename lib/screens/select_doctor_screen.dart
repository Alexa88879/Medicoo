import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doctor_appointment_detail_screen.dart'; // For navigation to the next screen
import '../models/doctor_model.dart'; // <<--- CORRECTED IMPORT

// The Doctor class definition is REMOVED from this file as it's now imported.

class SelectDoctorScreen extends StatefulWidget {
  final String specialization;
  const SelectDoctorScreen({super.key, required this.specialization});

  @override
  State<SelectDoctorScreen> createState() => _SelectDoctorScreenState();
}

class _SelectDoctorScreenState extends State<SelectDoctorScreen> {
  late Future<List<Doctor>> _doctorsFuture;

  @override
  void initState() {
    super.initState();
    _doctorsFuture = _fetchDoctorsBySpecialization(widget.specialization);
  }

  Future<List<Doctor>> _fetchDoctorsBySpecialization(String specialization) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .where('specialization', isEqualTo: specialization)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Doctor(
          uid: doc.id,
          name: data['displayName'] ?? data['fullName'] ?? 'N/A',
          specialization: data['specialization'] ?? 'N/A',
          profilePictureUrl: data['profilePictureUrl'],
          qualifications: data['qualifications'] as List<dynamic>?,
        );
      }).toList();
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
        backgroundColor: const Color(0xFF6EB6B4), // Theme color
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
            return Center(child: Text('Error: ${snapshot.error}'));
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
              String qualificationsText = (doctor.qualifications != null && doctor.qualifications!.isNotEmpty)
                                        ? doctor.qualifications!.join(', ')
                                        : 'Not specified'; // Changed from 'N/A' to 'Not specified'
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                elevation: 2.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: doctor.profilePictureUrl != null && doctor.profilePictureUrl!.isNotEmpty
                        ? NetworkImage(doctor.profilePictureUrl!)
                        : null,
                    child: doctor.profilePictureUrl == null || doctor.profilePictureUrl!.isEmpty
                        ? Icon(Icons.person, size: 30, color: Theme.of(context).primaryColor)
                        : null,
                  ),
                  title: Text(doctor.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${doctor.specialization}\n$qualificationsText'),
                  isThreeLine: qualificationsText != 'Not specified', // Make it three line if qualifications are present
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // Ensure DoctorAppointmentDetailScreen also imports Doctor from doctor_model.dart
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