// lib/data/sample_medical_events_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Note: For this to work, samplePatientsData and sampleDoctorsData
// need to be accessible, or their UIDs/PatientIDs need to be known.
// This example assumes UIDs will be assigned during seeding.
// For linking, we'll use indices into the samplePatientsData and sampleDoctorsData lists.

// --- SAMPLE APPOINTMENTS ---
// For each appointment, specify patientIndex and doctorIndex from your sample data lists.
// The actual UIDs will be resolved during the seeding process.
final List<Map<String, dynamic>> sampleAppointments = [
  // Priya Sharma (index 0)
  {
    "patientIndex": 0, // Priya Sharma
    "doctorIndex": 0,  // Dr. Ananya Sharma (Dental care)
    "appointmentDateOffset": -30, // 30 days ago
    "appointmentTime": "10:00 AM",
    "category": "Dental care", // Should match doctor's speciality
    "status": "completed",
    "diagnosis": "Dental Caries", // Example diagnosis
    "consultationNotes": "Patient presented with toothache. Advised filling for two molars. Follow-up in 6 months.",
    "hasPrescription": true, // Flag to generate a prescription for this appointment
    "hasLabReport": false,
  },
  {
    "patientIndex": 0, // Priya Sharma
    "doctorIndex": 2,  // Dr. Vikram Singh (Heart)
    "appointmentDateOffset": -90, // 90 days ago
    "appointmentTime": "11:30 AM",
    "category": "Heart",
    "status": "completed",
    "diagnosis": "Routine Cardiac Checkup",
    "consultationNotes": "ECG normal. Blood pressure slightly elevated. Advised lifestyle modifications.",
    "hasPrescription": true,
    "hasLabReport": true, // Flag to generate a lab report (e.g., lipid profile)
    "labReportName": "Lipid Profile"
  },
  // Amit Kumar (index 1)
  {
    "patientIndex": 1, // Amit Kumar
    "doctorIndex": 12, // Dr. Rahul Khanna (Eye Specialist)
    "appointmentDateOffset": -15,
    "appointmentTime": "03:00 PM",
    "category": "Eye Specialist",
    "status": "completed",
    "diagnosis": "Myopia",
    "consultationNotes": "Prescribed new eyeglasses. Yearly checkup recommended.",
    "hasPrescription": true, // For eye drops or glasses prescription
    "hasLabReport": false,
  },
  {
    "patientIndex": 1, // Amit Kumar
    "doctorIndex": 14, // Dr. Nandita Sen (Women's Health) - Example, can be any doctor
    "appointmentDateOffset": -200, // More than 6 months ago
    "appointmentTime": "09:00 AM",
    "category": "General physician", // Let's say it was for a general checkup
    "status": "completed",
    "diagnosis": "Seasonal Flu",
    "consultationNotes": "Prescribed rest and medication for flu symptoms.",
    "hasPrescription": true,
    "hasLabReport": false,
  },
  // Sunita Patel (index 2)
   {
    "patientIndex": 2, // Sunita Patel
    "doctorIndex": 7,  // Ms. Ritu Verma (Mental Wellness)
    "appointmentDateOffset": -60,
    "appointmentTime": "04:00 PM",
    "category": "Mental Wellness",
    "status": "completed",
    "diagnosis": "Mild Anxiety",
    "consultationNotes": "Discussed coping mechanisms. Scheduled follow-up sessions.",
    "hasPrescription": false, // Therapy might not always have medication
    "hasLabReport": false,
  },
  // Add more appointments for other patients and doctors...
  // For example, for Rajesh Singh (index 3) with Dr. Rajesh Pillai (Cancer, index 6)
  {
    "patientIndex": 3,
    "doctorIndex": 6,
    "appointmentDateOffset": -45,
    "appointmentTime": "10:30 AM",
    "category": "Cancer",
    "status": "completed",
    "diagnosis": "Follow-up Consultation",
    "consultationNotes": "Review of previous reports. Condition stable. Continue current medication.",
    "hasPrescription": true,
    "hasLabReport": true,
    "labReportName": "Tumor Marker Test"
  },
];

// --- SAMPLE PRESCRIPTIONS (linked to appointments by index) ---
// This structure assumes we generate prescription data based on the appointment.
// The seeder script will handle creating the actual prescription documents.
// We'll define sample medication lists here.
final Map<int, List<Map<String, String>>> sampleMedicationsForAppointmentIndex = {
  0: [ // For sampleAppointments[0] (Priya Sharma - Dental)
    {"medicineName": "Amoxicillin", "dosage": "250mg", "frequency": "Thrice a day", "duration": "5 days"},
    {"medicineName": "Ibuprofen", "dosage": "400mg", "frequency": "SOS for pain", "duration": "As needed"},
  ],
  1: [ // For sampleAppointments[1] (Priya Sharma - Heart)
    {"medicineName": "Aspirin", "dosage": "75mg", "frequency": "Once a day", "duration": "Ongoing"},
    {"medicineName": "Atorvastatin", "dosage": "10mg", "frequency": "Once at night", "duration": "3 months"},
  ],
  2: [ // For sampleAppointments[2] (Amit Kumar - Eye)
    {"medicineName": "Refresh Tears Eye Drops", "dosage": "1 drop in each eye", "frequency": "4 times a day", "duration": "1 month"},
  ],
   3: [ // For sampleAppointments[3] (Amit Kumar - Flu)
    {"medicineName": "Paracetamol", "dosage": "500mg", "frequency": "Thrice a day", "duration": "3 days"},
    {"medicineName": "Cetirizine", "dosage": "10mg", "frequency": "Once a day", "duration": "3 days"},
  ],
  // For sampleAppointments[5] (Rajesh Singh - Cancer)
  5: [
    {"medicineName": "Tamoxifen", "dosage": "20mg", "frequency": "Once a day", "duration": "Ongoing"},
    {"medicineName": "Calcium+D3", "dosage": "1 tablet", "frequency": "Once a day", "duration": "Ongoing"},
  ]
};

// --- SAMPLE LAB REPORTS (linked to appointments by index) ---
// The seeder script will handle creating the actual medical_report documents.
// We define basic info here.
final Map<int, Map<String, dynamic>> sampleLabReportInfoForAppointmentIndex = {
  1: { // For sampleAppointments[1] (Priya Sharma - Heart)
    "reportName": "Lipid Profile Test",
    "fileUrl": "https://www.example.com/reports/lipid_profile_priya.pdf", // Placeholder URL
    "summaryOrKeyFindings": "Total Cholesterol: 220 mg/dL, LDL: 150 mg/dL. Advised dietary control."
  },
  5: { // For sampleAppointments[5] (Rajesh Singh - Cancer)
    "reportName": "Tumor Marker CA-125",
    "fileUrl": "https://www.example.com/reports/ca125_rajesh.pdf", // Placeholder URL
    "summaryOrKeyFindings": "CA-125 level within normal limits. No significant change from previous."
  },
};
