// lib/screens/admin_data_seeder_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/sample_doctors_data.dart'; // Import your sample data

class AdminDataSeederScreen extends StatefulWidget {
  const AdminDataSeederScreen({super.key});

  @override
  State<AdminDataSeederScreen> createState() => _AdminDataSeederScreenState();
}

class _AdminDataSeederScreenState extends State<AdminDataSeederScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _statusMessage = "";

  Future<void> _seedAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _statusMessage = "Starting data seeding...\n";
    });

    // 1. Seed Categories (same as before)
    _statusMessage += "Seeding categories...\n";
    if (mounted) setState(() {});
    int categoriesAdded = 0;
    int categoriesExist = 0;
    for (var categoryData in sampleCategoriesData) {
      try {
        final categoryRef = _firestore.collection('categories').doc(categoryData['name']!.toLowerCase().replaceAll(' ', '-').replaceAll('&', 'and'));
        final categoryDoc = await categoryRef.get();
        if (!categoryDoc.exists) {
          await categoryRef.set({
            'name': categoryData['name'],
            'description': categoryData['description'],
            'imageUrl': categoryData['imageUrl'],
          });
          categoriesAdded++;
          _statusMessage += "Added category: ${categoryData['name']}\n";
        } else {
          categoriesExist++;
          _statusMessage += "Category already exists: ${categoryData['name']}\n";
        }
        if (mounted) setState(() {});
      } catch (e) {
        _statusMessage += "Error adding category ${categoryData['name']}: $e\n";
        if (mounted) setState(() {});
      }
    }
    _statusMessage += "$categoriesAdded categories added, $categoriesExist categories already existed.\n\n";
    if (mounted) setState(() {});


    // 2. Seed Doctors
    _statusMessage += "Seeding doctors...\n";
    if (mounted) setState(() {});
    int doctorsProcessed = 0;
    int authUsersCreated = 0;
    int authUsersSkippedCreationDueToKnownUID = 0;
    int authUsersExistSkippedNoUID = 0;
    int firestoreDoctorsProcessed = 0; // Renamed for clarity (created or updated)
    int firestoreUsersProcessed = 0;   // Renamed for clarity

    for (var doctorData in sampleDoctorsData) {
      doctorsProcessed++;
      String doctorEmail = "${doctorData['emailPrefix']}@gmail.com";
      String doctorPassword = "123456"; // Only used if creating new Auth user
      String doctorName = doctorData['name'];
      String? doctorAuthUID = doctorData['knownAuthUID'] as String?; // Get knownAuthUID
      bool authUserNewlyCreated = false;

      _statusMessage += "\nProcessing: $doctorName ($doctorEmail)...\n";
      if (mounted) setState(() {});

      try {
        // A. Handle Firebase Auth User
        if (doctorAuthUID != null && doctorAuthUID.isNotEmpty) {
          _statusMessage += "  Using provided knownAuthUID: $doctorAuthUID\n";
          authUsersSkippedCreationDueToKnownUID++;
          // Optionally, verify this UID actually exists in Auth, or update its display name/email if needed.
          // For simplicity, this script assumes the provided UID is correct and exists.
          // You might want to update the display name in Auth if it's different:
          // User? existingUser = _auth.currentUser; // This is the admin user
          // If you have admin SDK access, you could update other users. Client-side, this is limited.
        } else {
          // No knownAuthUID, attempt to create Auth user
          _statusMessage += "  No knownAuthUID provided. Attempting to create Auth user...\n";
          try {
            UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
              email: doctorEmail,
              password: doctorPassword,
            );
            doctorAuthUID = userCredential.user?.uid;
            if (doctorAuthUID != null) {
              authUsersCreated++;
              authUserNewlyCreated = true;
              _statusMessage += "  Auth user CREATED: $doctorAuthUID\n";
              await userCredential.user?.updateDisplayName(doctorName);
            }
          } on FirebaseAuthException catch (e) {
            if (e.code == 'email-already-in-use') {
              authUsersExistSkippedNoUID++;
              _statusMessage += "  Auth user already exists for $doctorEmail, but no knownAuthUID was provided. Skipping Firestore docs for this doctor.\n";
              if (mounted) setState(() {});
              continue; // Skip to next doctor
            } else {
              _statusMessage += "  FirebaseAuthException for $doctorEmail: ${e.message}\n";
              if (mounted) setState(() {});
              rethrow;
            }
          }
        }

        if (doctorAuthUID == null || doctorAuthUID.isEmpty) {
           _statusMessage += "  Could not obtain/determine Auth UID for $doctorEmail. Skipping Firestore docs.\n";
           if (mounted) setState(() {});
           continue;
        }

        // B. Create/Update Firestore 'doctors' document
        Map<String, dynamic> doctorProfile = {
          'doctorUID': doctorAuthUID, 
          'name': doctorName,
          'email': doctorEmail,
          'phoneNumber': doctorData['phoneNumber'],
          'imageUrl': doctorData['imageUrl'], 
          'bio': doctorData['bio'],
          'speciality': doctorData['speciality'],
          'qualifications': doctorData['qualifications'],
          'yearsOfExperience': doctorData['yearsOfExperience'],
          'consultationFee': doctorData['consultationFee'],
          'isAvailable': true,
          'availableSlots': doctorData['availableSlots'] ?? defaultAvailableSlots,
          'licenseNumber': doctorData['licenseNumber'],
          'hospitalAffiliations': doctorData['hospitalAffiliations'],
          'rating': doctorData['rating'],
          'totalRatings': doctorData['totalRatings'],
          'role': 'doctor', 
          'address': doctorData['address'],
          'servicesOffered': doctorData['servicesOffered'],
          'languagesSpoken': doctorData['languagesSpoken'],
          'updatedAt': FieldValue.serverTimestamp(),
        };
        // Only set createdAt if it's a new document (i.e., Auth user was newly created, implying doctor doc is also new)
        // If using knownAuthUID, we assume we might be updating, so don't overwrite createdAt.
        if (authUserNewlyCreated) { 
            doctorProfile['createdAt'] = FieldValue.serverTimestamp();
        }
        await _firestore.collection('doctors').doc(doctorAuthUID).set(doctorProfile, SetOptions(merge: true));
        firestoreDoctorsProcessed++;
        _statusMessage += "  Firestore 'doctors' doc created/updated.\n";
        if (mounted) setState(() {});

        // C. Create/Update Firestore 'users' document for the doctor
        Map<String, dynamic> userProfileForDoctor = {
          'uid': doctorAuthUID,
          'email': doctorEmail,
          'displayName': doctorName,
          'photoURL': doctorData['imageUrl'], 
          'providerId': 'password', // Assuming these are email/password accounts
          'role': 'doctor',
          'age': null,
          'bloodGroup': null,
          'patientId': null, 
          'fcmToken': null,
          'phoneNumber': doctorData['phoneNumber'],
        };
        if (authUserNewlyCreated) { 
            userProfileForDoctor['createdAt'] = FieldValue.serverTimestamp();
        }
        await _firestore.collection('users').doc(doctorAuthUID).set(userProfileForDoctor, SetOptions(merge: true));
        firestoreUsersProcessed++;
        _statusMessage += "  Firestore 'users' doc created/updated for doctor role.\n";
        if (mounted) setState(() {});

      } catch (e) {
        _statusMessage += "  Error processing $doctorName ($doctorEmail): $e\n";
        if (mounted) setState(() {});
      }
    }

    _statusMessage += "\n--- Seeding Summary ---\n";
    _statusMessage += "$doctorsProcessed doctors processed in sample data.\n";
    _statusMessage += "$authUsersCreated NEW Auth users created.\n";
    _statusMessage += "$authUsersSkippedCreationDueToKnownUID Auth users processed using provided knownAuthUID.\n";
    _statusMessage += "$authUsersExistSkippedNoUID existing Auth users SKIPPED (email existed, no knownAuthUID).\n";
    _statusMessage += "$firestoreDoctorsProcessed 'doctors' documents created/updated.\n";
    _statusMessage += "$firestoreUsersProcessed 'users' documents for doctors created/updated.\n";
    _statusMessage += "--- End of Seeding ---\n";

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: Seed Sample Data'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This tool will populate your Firestore database with sample categories and doctor profiles. If `knownAuthUID` is provided for a doctor in `sample_doctors_data.dart`, it will use that UID; otherwise, it will attempt to create a new Firebase Authentication account.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 10),
            const Text(
              'WARNING: Ensure your Firestore rules (temporarily) allow these operations. If creating new Auth users, ensure emails are unique.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
             const SizedBox(height: 10),
            const Text(
              'Make sure to complete the `sampleDoctorsData` list in `lib/data/sample_doctors_data.dart` with 2-3 doctors for all 18 categories and include `knownAuthUID` for existing Auth users.',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.data_saver_on),
                    label: const Text('Seed Doctor and Category Data', style: TextStyle(fontSize: 16)),
                    onPressed: _seedAllData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                  ),
            const SizedBox(height: 20),
            const Text(
              'Log:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              height: 300, 
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: SingleChildScrollView(
                child: Text(_statusMessage, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
