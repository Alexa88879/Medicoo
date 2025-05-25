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
    debugPrint("[Medication.fromMap] Parsing map: $map");
    return Medication(
      medicineName: map['medicineName']?.toString() ?? 'N/A', // Ensure string
      dosage: map['dosage']?.toString() ?? 'N/A',             // Ensure string
      frequency: map['frequency']?.toString() ?? 'N/A',         // Ensure string
      duration: map['duration']?.toString() ?? 'N/A',          // Convert to string if not null
    );
  }
}

class Prescription {
  final String id;
  final String patientId;
  final String doctorId;
  final String doctorName;
  final String? patientName;
  final String appointmentId;
  final Timestamp issueDate;
  final List<Medication> medications;
  final String? notes;
  final String? diagnosis;
  final String? status;
  final String? advice;

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
    this.advice,
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
      patientId: data['patientId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? 'N/A',
      patientName: data['patientName'],
      appointmentId: data['appointmentId'] ?? '',
      issueDate: data['issuedDate'] ?? Timestamp.now(),
      medications: medsList,
      notes: data['notes'],
      diagnosis: data['diagnosis'],
      status: data['status'],
      advice: data['advice'],
    );
  }
}
