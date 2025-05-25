// lib/models/record_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Model for the summary displayed in the RecordsListScreen
class MedicalRecordSummary {
  final String id; // Typically appointmentId
  final String doctorName; // Added
  final String doctorSpecialty; // Added
  final String year;
  final String period; // Could be the formatted date of the appointment
  final String? patientAgeAtEvent; // User's age at the time of the event
  final Timestamp eventTimestamp; // For sorting

  MedicalRecordSummary({
    required this.id,
    required this.doctorName, // Added
    required this.doctorSpecialty, // Added
    required this.year,
    required this.period,
    this.patientAgeAtEvent,
    required this.eventTimestamp,
  });
}

// Model for the detailed view (can be expanded or composed)
// For now, we'll fetch data directly in RecordDetailScreen, but a model can be useful
// class MedicalRecordDetail {
//   final String appointmentId;
//   final String doctorName;
//   final String doctorSpeciality;
//   final Timestamp appointmentDateTime;
//   final String? diagnosis;
//   final List<LabReport> labReports;
//   final List<PrescribedMedicine> prescribedMedicines;
//   final List<TherapySession> therapySessions; // Example

//   MedicalRecordDetail({
//     required this.appointmentId,
//     required this.doctorName,
//     // ... other fields
//   });
// }

// Example sub-models if you create a full MedicalRecordDetail
// class LabReport {
//   final String testName;
//   final String reportUrl; // Link to PDF/image in Firebase Storage
//   final Timestamp date;
//   LabReport({required this.testName, required this.reportUrl, required this.date});
// }

// class PrescribedMedicine {
//   final String name;
//   final String strength;
//   final String dosage; // e.g., "1 tablet", "10ml"
//   final String frequency; // e.g., "Twice a day"
//   final String duration; // e.g., "7 days"
//   PrescribedMedicine({required this.name, required this.strength, required this.dosage, required this.frequency, required this.duration});
// }
