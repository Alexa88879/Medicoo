// lib/screens/admin_data_seeder_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../data/sample_doctors_data.dart'; 
import '../data/sample_patients_data.dart'; 
import '../data/sample_medical_events_data.dart'; 

class AdminDataSeederScreen extends StatefulWidget {
  const AdminDataSeederScreen({super.key});

  @override
  State<AdminDataSeederScreen> createState() => _AdminDataSeederScreenState();
}

class _AdminDataSeederScreenState extends State<AdminDataSeederScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSeedingCategoriesDoctors = false;
  bool _isSeedingPatients = false;
  bool _isSeedingMedicalEvents = false;
  String _statusMessage = "";

  // Store UIDs of created/verified users for linking
  final Map<int, String> _patientIndexToUID = {};
  final Map<int, String> _doctorIndexToUID = {};


  Future<void> _seedCategories() async {
    if (!mounted) return;
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
  }

  Future<void> _seedDoctorData() async {
    if (!mounted) return;
    setState(() {
      _isSeedingCategoriesDoctors = true; 
      _statusMessage = "Starting CATEGORY & DOCTOR data seeding...\n";
    });

    await _seedCategories(); 

    _statusMessage += "Seeding doctors...\n";
    if (mounted) setState(() {});
    int doctorsProcessed = 0;
    int authUsersCreated = 0;
    int authUsersSkippedCreationDueToKnownUID = 0;
    int authUsersExistSkippedNoUID = 0;
    int firestoreDoctorsProcessed = 0;
    int firestoreUsersProcessed = 0;
    _doctorIndexToUID.clear(); 

    for (int i = 0; i < sampleDoctorsData.length; i++) {
      var doctorData = sampleDoctorsData[i];
      doctorsProcessed++;
      String doctorEmail = "${doctorData['emailPrefix']}@gmail.com";
      String doctorPassword = "123456";
      String doctorName = doctorData['name'];
      String? doctorAuthUID = doctorData['knownAuthUID'] as String?;
      bool authUserNewlyCreated = false;

      _statusMessage += "\nProcessing Doctor: $doctorName ($doctorEmail)...\n";
      if (mounted) setState(() {});

      try {
        if (doctorAuthUID != null && doctorAuthUID.isNotEmpty) {
          _statusMessage += "  Using provided knownAuthUID for doctor: $doctorAuthUID\n";
          authUsersSkippedCreationDueToKnownUID++;
          _doctorIndexToUID[i] = doctorAuthUID; 
        } else {
          _statusMessage += "  No knownAuthUID for doctor. Attempting to create Auth user...\n";
          try {
            UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
              email: doctorEmail,
              password: doctorPassword,
            );
            doctorAuthUID = userCredential.user?.uid;
            if (doctorAuthUID != null) {
              authUsersCreated++;
              authUserNewlyCreated = true;
              _doctorIndexToUID[i] = doctorAuthUID; 
              _statusMessage += "  Auth user CREATED for doctor: $doctorAuthUID\n";
              await userCredential.user?.updateDisplayName(doctorName);
            }
          } on FirebaseAuthException catch (e) {
            if (e.code == 'email-already-in-use') {
              authUsersExistSkippedNoUID++;
              _statusMessage += "  Auth user already exists for $doctorEmail, but no knownAuthUID was provided. Firestore docs might not be linked correctly if UID is unknown. Please add knownAuthUID to sample_doctors_data.dart for this doctor if you want to link events to them.\n";
              // We cannot reliably get UID here client-side if not provided and creation failed.
            } else {
              _statusMessage += "  FirebaseAuthException for $doctorEmail: ${e.message}\n";
              if (mounted) setState(() {});
              throw e; 
            }
          }
        }

        if (doctorAuthUID == null || doctorAuthUID.isEmpty) {
           _statusMessage += "  Could not obtain/determine Auth UID for $doctorEmail. Skipping Firestore docs for this doctor.\n";
           if (mounted) setState(() {});
           continue;
        }

        Map<String, dynamic> doctorProfile = {
          'doctorUID': doctorAuthUID, 'name': doctorName, 'email': doctorEmail,
          'phoneNumber': doctorData['phoneNumber'], 'imageUrl': doctorData['imageUrl'], 
          'bio': doctorData['bio'], 'speciality': doctorData['speciality'],
          'qualifications': doctorData['qualifications'], 'yearsOfExperience': doctorData['yearsOfExperience'],
          'consultationFee': doctorData['consultationFee'], 'isAvailable': true,
          'availableSlots': doctorData['availableSlots'] ?? defaultAvailableSlots, 
          'licenseNumber': doctorData['licenseNumber'], 'hospitalAffiliations': doctorData['hospitalAffiliations'],
          'rating': doctorData['rating'], 'totalRatings': doctorData['totalRatings'],
          'role': 'doctor', 'address': doctorData['address'],
          'servicesOffered': doctorData['servicesOffered'], 'languagesSpoken': doctorData['languagesSpoken'],
          'updatedAt': FieldValue.serverTimestamp(),
        };
        // Set createdAt only if we are sure it's a new document context
        bool doctorDocExists = (await _firestore.collection('doctors').doc(doctorAuthUID).get()).exists;
        if (authUserNewlyCreated || !doctorDocExists) { 
            doctorProfile['createdAt'] = FieldValue.serverTimestamp();
        }
        await _firestore.collection('doctors').doc(doctorAuthUID).set(doctorProfile, SetOptions(merge: true));
        firestoreDoctorsProcessed++;
        _statusMessage += "  Firestore 'doctors' doc created/updated.\n";
        
        Map<String, dynamic> userProfileForDoctor = {
          'uid': doctorAuthUID, 'email': doctorEmail, 'displayName': doctorName,
          'photoURL': doctorData['imageUrl'], 'providerId': 'password', 'role': 'doctor',
          'age': null, 'bloodGroup': null, 'patientId': null, 
          'fcmToken': null, 'phoneNumber': doctorData['phoneNumber'],
          'updatedAt': FieldValue.serverTimestamp(),
        };
        bool userDocForDoctorExists = (await _firestore.collection('users').doc(doctorAuthUID).get()).exists;
        if (authUserNewlyCreated || !userDocForDoctorExists) { 
            userProfileForDoctor['createdAt'] = FieldValue.serverTimestamp();
        }
        await _firestore.collection('users').doc(doctorAuthUID).set(userProfileForDoctor, SetOptions(merge: true));
        firestoreUsersProcessed++;
        _statusMessage += "  Firestore 'users' doc created/updated for doctor role.\n";
        if (mounted) setState(() {});

      } catch (e) {
        _statusMessage += "  Error processing Doctor $doctorName ($doctorEmail): $e\n";
        if (mounted) setState(() {});
      }
    }
    _statusMessage += "\n--- Doctor & Category Seeding Summary ---\n${doctorsProcessed} doctors processed. $authUsersCreated NEW Auth users. $authUsersSkippedCreationDueToKnownUID used known UIDs. $authUsersExistSkippedNoUID existing email, UID unknown. $firestoreDoctorsProcessed doctor docs. $firestoreUsersProcessed user docs for doctors.\n--- End Doctor & Category Seeding ---\n\n";
    if (mounted) setState(() => _isSeedingCategoriesDoctors = false);
  }

  Future<void> _seedPatientData() async {
    if (!mounted) return;
    setState(() {
      _isSeedingPatients = true;
      _statusMessage += "Starting PATIENT data seeding...\n";
    });

    int patientsProcessed = 0;
    int authPatientsCreated = 0;
    int authPatientsSkippedKnownUID = 0;
    int authPatientsSkippedExistingEmail = 0;
    int firestorePatientsCreated = 0;
    _patientIndexToUID.clear();

    for (int i = 0; i < samplePatientsData.length; i++) {
      var patientData = samplePatientsData[i];
      patientsProcessed++;
      String patientEmail = "${patientData['emailPrefix']}@gmail.com"; 
      String patientPassword = "123456"; 
      String patientName = patientData['displayName'];
      String? patientAuthUID = patientData['knownAuthUID'] as String?;
      bool authUserNewlyCreated = false;

      _statusMessage += "\nProcessing Patient: $patientName ($patientEmail)...\n";
      if (mounted) setState(() {});

      try {
        if (patientAuthUID != null && patientAuthUID.isNotEmpty) {
          _statusMessage += "  Using provided knownAuthUID for patient: $patientAuthUID\n";
          authPatientsSkippedKnownUID++;
          _patientIndexToUID[i] = patientAuthUID;
        } else {
          _statusMessage += "  No knownAuthUID for patient. Attempting to create Auth user...\n";
          try {
            UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
              email: patientEmail,
              password: patientPassword,
            );
            patientAuthUID = userCredential.user?.uid;
            if (patientAuthUID != null) {
              authPatientsCreated++;
              authUserNewlyCreated = true;
              _patientIndexToUID[i] = patientAuthUID;
              _statusMessage += "  Auth user CREATED for patient: $patientAuthUID\n";
              await userCredential.user?.updateDisplayName(patientName);
            }
          } on FirebaseAuthException catch (e) {
            if (e.code == 'email-already-in-use') {
              authPatientsSkippedExistingEmail++;
              _statusMessage += "  Auth user already exists for $patientEmail, but no knownAuthUID was provided. Skipping Firestore doc for this patient.\n";
              if (mounted) setState(() {});
              continue; 
            } else {
              throw e; 
            }
          }
        }

        if (patientAuthUID == null || patientAuthUID.isEmpty) {
           _statusMessage += "  Could not obtain/determine Auth UID for $patientEmail. Skipping Firestore doc.\n";
           if (mounted) setState(() {});
           continue;
        }

        String currentPatientId = patientData['patientId'] ?? 'PAT_ERR_${DateTime.now().millisecondsSinceEpoch}';

        Map<String, dynamic> userProfileForPatient = {
          'uid': patientAuthUID, 'email': patientEmail, 'displayName': patientName,
          'photoURL': patientData['photoURL'], 'providerId': 'password',
          'role': 'patient', 'age': patientData['age'], 'bloodGroup': patientData['bloodGroup'],
          'patientId': currentPatientId, 'fcmToken': null, 'phoneNumber': patientData['phoneNumber'],
          'updatedAt': FieldValue.serverTimestamp(),
        };
        bool userDocForPatientExists = (await _firestore.collection('users').doc(patientAuthUID).get()).exists;
         if (authUserNewlyCreated || !userDocForPatientExists) { 
            userProfileForPatient['createdAt'] = FieldValue.serverTimestamp();
        }

        await _firestore.collection('users').doc(patientAuthUID).set(userProfileForPatient, SetOptions(merge: true));
        firestorePatientsCreated++;
        _statusMessage += "  Firestore 'users' doc created/updated for patient.\n";
        if (mounted) setState(() {});

      } catch (e) {
        _statusMessage += "  Error processing Patient $patientName ($patientEmail): $e\n";
        if (mounted) setState(() {});
      }
    }
    _statusMessage += "\n--- Patient Seeding Summary ---\n$patientsProcessed patients processed. $authPatientsCreated NEW Auth users. $authPatientsSkippedKnownUID used known UIDs. $authPatientsSkippedExistingEmail existing email, UID unknown. $firestorePatientsCreated user docs for patients.\n--- End Patient Seeding ---\n\n";
    if (mounted) setState(() => _isSeedingPatients = false);
  }

  Future<void> _seedMedicalEvents() async {
    if (_patientIndexToUID.isEmpty) {
      _statusMessage += "Patient UIDs not available. Please seed PATIENTS first (and ensure some were created or known UIDs were used).\n";
      if (mounted) setState(() {});
      return;
    }
     if (_doctorIndexToUID.isEmpty) {
      _statusMessage += "Doctor UIDs not available. Please seed DOCTORS & CATEGORIES first (and ensure some were created or known UIDs were used).\n";
      if (mounted) setState(() {});
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSeedingMedicalEvents = true;
      _statusMessage += "Starting MEDICAL EVENTS (Appointments, Prescriptions, Reports) seeding...\n";
    });

    int appointmentsCreated = 0;
    int prescriptionsCreated = 0;
    int labReportsCreated = 0;

    for (int i = 0; i < sampleAppointments.length; i++) {
      var appData = sampleAppointments[i];
      int patientDataIndex = appData['patientIndex'];
      int doctorDataIndex = appData['doctorIndex'];

      String? patientUID = _patientIndexToUID[patientDataIndex];
      String? doctorUID = _doctorIndexToUID[doctorDataIndex];
      
      if (patientUID == null || doctorUID == null || 
          patientDataIndex >= samplePatientsData.length || 
          doctorDataIndex >= sampleDoctorsData.length) {
        _statusMessage += "Skipping appointment for patientIndex $patientDataIndex / doctorIndex $doctorDataIndex due to missing UID or invalid index in sample data lists.\n";
        continue;
      }
      Map<String, dynamic> patientDetails = samplePatientsData[patientDataIndex];
      Map<String, dynamic> doctorDetails = sampleDoctorsData[doctorDataIndex];


      _statusMessage += "  Processing event for ${patientDetails['displayName']} with ${doctorDetails['name']}...\n";
      if(mounted) setState((){});

      try {
        DateTime now = DateTime.now();
        DateTime appointmentDateTime = DateTime(now.year, now.month, now.day)
                                      .add(Duration(days: appData['appointmentDateOffset']));
        
        final timeFormat = DateFormat('hh:mm a');
        final parsedTime = timeFormat.parse(appData['appointmentTime']);
        appointmentDateTime = DateTime(
          appointmentDateTime.year, appointmentDateTime.month, appointmentDateTime.day,
          parsedTime.hour, parsedTime.minute
        );

        DocumentReference appointmentRef = _firestore.collection('appointments').doc();
        Map<String, dynamic> appointmentToSet = {
          'appointmentId': appointmentRef.id,
          'userId': patientUID,
          'userName': patientDetails['displayName'],
          'doctorId': doctorUID,
          'doctorName': doctorDetails['name'],
          'doctorSpeciality': appData['category'], 
          'appointmentDate': DateFormat('yyyy-MM-dd').format(appointmentDateTime),
          'appointmentTime': appData['appointmentTime'],
          'dateTimeFull': Timestamp.fromDate(appointmentDateTime),
          'category': appData['category'],
          'status': appData['status'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'notes': appData['consultationNotes'] ?? '',
          'diagnosis': appData['diagnosis'] ?? 'N/A',
        };
        await appointmentRef.set(appointmentToSet);
        appointmentsCreated++;
        _statusMessage += "    Created Appointment: ${appointmentRef.id}\n";

        if (appData['hasPrescription'] == true && sampleMedicationsForAppointmentIndex.containsKey(i)) {
          DocumentReference presRef = _firestore.collection('prescriptions').doc();
          await presRef.set({
            'prescriptionId': presRef.id, 'userId': patientUID, 'userName': patientDetails['displayName'],
            'doctorId': doctorUID, 'doctorName': doctorDetails['name'], 'appointmentId': appointmentRef.id,
            'issueDate': Timestamp.fromDate(appointmentDateTime), 
            'medications': sampleMedicationsForAppointmentIndex[i],
            'diagnosis': appData['diagnosis'] ?? 'N/A',
            'advice': 'Follow medication as prescribed. Drink plenty of water.',
          });
          prescriptionsCreated++;
          _statusMessage += "      Linked Prescription: ${presRef.id}\n";
        }

        if (appData['hasLabReport'] == true && sampleLabReportInfoForAppointmentIndex.containsKey(i)) {
          Map<String, dynamic> reportInfo = sampleLabReportInfoForAppointmentIndex[i]!;
          DocumentReference reportRef = _firestore.collection('medical_reports').doc();
          await reportRef.set({
            'reportId': reportRef.id, 'userId': patientUID, 'linkedAppointmentId': appointmentRef.id,
            'reportName': reportInfo['reportName'] ?? appData['labReportName'] ?? 'Lab Report',
            'reportType': 'lab_test', 'issuingEntityName': 'Sample Lab Services',
            'dateOfReport': Timestamp.fromDate(appointmentDateTime.add(const Duration(days:1))), 
            'fileUrl': reportInfo['fileUrl'],
            'fileName': "${(reportInfo['reportName'] ?? 'report').replaceAll(' ', '_')}_${patientUID.substring(0,5)}.pdf",
            'summaryOrKeyFindings': reportInfo['summaryOrKeyFindings'],
            'uploadedAt': FieldValue.serverTimestamp(),
          });
          labReportsCreated++;
           _statusMessage += "      Linked Lab Report: ${reportRef.id}\n";
        }
        if (mounted) setState(() {});
      } catch (e) {
        _statusMessage += "    Error creating medical event for appointment index $i: $e\n";
        if (mounted) setState(() {});
      }
    }
    _statusMessage += "\n--- Medical Events Seeding Summary ---\n$appointmentsCreated appointments. $prescriptionsCreated prescriptions. $labReportsCreated lab reports.\n--- End Medical Events Seeding ---\n";
    if (mounted) setState(() => _isSeedingMedicalEvents = false);
  }


  @override
  Widget build(BuildContext context) {
    bool anySeedingInProgress = _isSeedingCategoriesDoctors || _isSeedingPatients || _isSeedingMedicalEvents;
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
              'This tool populates Firestore with sample data and creates Firebase Authentication accounts.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 10),
            const Text(
              'WARNING: Ensure Firestore rules are temporarily permissive. If Auth users already exist for the generated emails, provide `knownAuthUID` in sample data or they might be skipped/fail.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
             const SizedBox(height: 10),
            const Text(
              'Complete `sampleDoctorsData`, `samplePatientsData`, and `sampleMedicalEventsData` lists before running. Seed in order: Categories/Doctors -> Patients -> Medical Events.',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.medical_services_outlined),
              label: const Text('Seed Categories & Doctors', style: TextStyle(fontSize: 16)),
              onPressed: anySeedingInProgress ? null : _seedDoctorData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Seed Patients', style: TextStyle(fontSize: 16)),
              onPressed: anySeedingInProgress ? null : _seedPatientData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              icon: const Icon(Icons.receipt_long),
              label: const Text('Seed Medical Events', style: TextStyle(fontSize: 16)),
              onPressed: anySeedingInProgress ? null : _seedMedicalEvents,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
            const SizedBox(height: 20),
            if (anySeedingInProgress)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: Center(child: CircularProgressIndicator()),
              ),
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
                color: Colors.grey[100]
              ),
              child: SingleChildScrollView(
                reverse: true, 
                child: Text(_statusMessage, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
