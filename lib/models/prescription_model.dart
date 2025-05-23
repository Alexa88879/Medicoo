// lib/models/prescription_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class Medication {
  final String medicineName;
  final String dosage;
  final String frequency;
  final String duration;

  Medication({
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.duration,
  });

  factory Medication.fromMap(Map<String, dynamic> map) {
    // Added debug print for medication parsing
    debugPrint("[Medication.fromMap] Parsing map: $map");
    return Medication(
      medicineName: map['medicineName'] ?? 'N/A',
      dosage: map['dosage'] ?? 'N/A',
      frequency: map['frequency'] ?? 'N/A',
      duration: map['duration'] ?? 'N/A',
    );
  }
}

class Prescription {
  final String id;
  final String patientId; // To match your Firestore data
  final String doctorId;
  final String doctorName;
  final String? patientName;
  final String appointmentId;
  final Timestamp issueDate; // To match 'issuedDate' from your Firestore sample
  final List<Medication> medications;
  final String? notes;
  final String? diagnosis;
  final String? status;

  Prescription({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    this.patientName,
    required this.appointmentId,
    required this.issueDate,
    required this.medications,
    this.notes,
    this.diagnosis,
    this.status,
  });

  factory Prescription.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    debugPrint("[Prescription.fromFirestore] Parsing doc ${doc.id}, data: $data");
    var medsList = <Medication>[];
    if (data['medications'] is List) {
      debugPrint("[Prescription.fromFirestore] 'medications' is a List with ${(data['medications']as List).length} items.");
      for (var medMap in (data['medications'] as List)) {
        if (medMap is Map<String, dynamic>) {
          medsList.add(Medication.fromMap(medMap));
        } else {
          debugPrint("[Prescription.fromFirestore] Found non-map item in medications list: $medMap");
        }
      }
    } else {
       debugPrint("[Prescription.fromFirestore] 'medications' field is not a List or is null. Actual type: ${data['medications'].runtimeType}, Value: ${data['medications']}");
    }
    debugPrint("[Prescription.fromFirestore] Parsed ${medsList.length} medications for doc ${doc.id}.");


    return Prescription(
      id: doc.id,
      patientId: data['patientId'] ?? '', // Using patientId from your sample
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? 'N/A',
      patientName: data['patientName'], // This was in your sample
      appointmentId: data['appointmentId'] ?? '',
      issueDate: data['issuedDate'] ?? Timestamp.now(), // Using issuedDate from your sample
      medications: medsList,
      notes: data['notes'], // Assuming 'notes' might exist
      diagnosis: data['diagnosis'], // From your sample
      status: data['status'], // From your sample
    );
  }
}
