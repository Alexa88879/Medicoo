// import 'package:cloud_firestore/cloud_firestore.dart';

// class TestDataGenerator {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   Future<void> generateDoctorTestData(int count) async {
//     Map<String, List<String>> specializationQualifications = {
//       'Cancer': ['MBBS', 'MD', 'DM Oncology'],
//       'Ayurveda': ['BAMS', 'MD Ayurveda'],
//       'Mental Wellness': ['MBBS', 'MD Psychiatry', 'DNB Psychiatry'],
//       'Homoeopath': ['BHMS', 'MD Homeopathy'],
//       'Physiotherapy': ['BPT', 'MPT', 'DPT'],
//       'General Surgery': ['MBBS', 'MS Surgery', 'DNB Surgery'],
//       'Urinary Issues': ['MBBS', 'MS Urology', 'DNB Urology'],
//       'Lungs and Breathing': ['MBBS', 'MD Pulmonology', 'DM Pulmonology'],
//       'General physician': ['MBBS', 'MD Internal Medicine'],
//       'Eye Specialist': ['MBBS', 'MS Ophthalmology', 'DNB Ophthalmology'],
//       'Women\'s Health': ['MBBS', 'MD Gynecology', 'DNB Gynecology'],
//       'Diet & Nutrition': ['BSc Nutrition', 'MSc Nutrition', 'PhD Nutrition'],
//       'Skin & Hair': ['MBBS', 'MD Dermatology', 'DNB Dermatology'],
//       'Bones & Joints': ['MBBS', 'MS Orthopedics', 'DNB Orthopedics'],
//       'Child Specialist': ['MBBS', 'MD Pediatrics', 'DNB Pediatrics'],
//       'Dental care': ['BDS', 'MDS', 'DNB Dentistry'],
//       'Heart': ['MBBS', 'MD Cardiology', 'DM Cardiology'],
//       'Kidney Issues': ['MBBS', 'MD Nephrology', 'DM Nephrology'],
//     };

//     List<String> hospitalIds = ['hosp1234', 'hosp5678', 'hosp9012', 'hosp3456'];
//     int doctorCounter = 100;

//     for (var entry in specializationQualifications.entries) {
//       String specialization = entry.key;
//       List<String> qualifications = entry.value;

//       // Generate 2-3 doctors for each specialization
//       int doctorsForSpecialization = 2 + (DateTime.now().millisecondsSinceEpoch % 2); // Random 2 or 3

//       for (int i = 0; i < doctorsForSpecialization; i++) {
//         String doctorId = 'DOC${doctorCounter++}';
        
//         // Generate random years of experience between 5 and 30
//         int yearsExperience = 5 + (DateTime.now().millisecondsSinceEpoch % 25);
        
//         // Generate random consultation fee between 500 and 2000
//         int consultationFee = 500 + (DateTime.now().millisecondsSinceEpoch % 1500);

//         // Select qualifications for this doctor
//         List<String> doctorQualifications = [
//           qualifications[0], // Always include basic qualification
//           qualifications[qualifications.length > 1 ? 1 : 0], // Add second qualification if available
//           if (qualifications.length > 2 && i % 2 == 0) qualifications[2], // Add third qualification for some doctors
//         ];

//         await _firestore.collection('users').doc(doctorId).set({
//           'displayName': 'Dr. $_getRandomName() $doctorCounter',
//           'email': 'doctor$doctorCounter@example.com',
//           'phoneNumber': '91${9000000000 + doctorCounter}',
//           'role': 'doctor',
//           'specialization': specialization,
//           'qualifications': doctorQualifications,
//           'yearsExperience': yearsExperience,
//           'consultationFee': consultationFee,
//           'isActive': true,
//           'licenseNumber': 'MEDIC${3000 + doctorCounter}',
//           'hospitalAffiliations': [hospitalIds[doctorCounter % hospitalIds.length]],
//           'rating': 4.0 + (doctorCounter % 10) / 10, // Random rating between 4.0 and 4.9
//           'totalRatings': 50 + (doctorCounter % 150), // Random number of ratings
//           'about': 'Experienced $specialization specialist with $yearsExperience years of practice.',
//         });
//       }
//     }
//   }

//   String _getRandomName() {
//     List<String> names = [
//       'Smith', 'Johnson', 'Williams', 'Brown', 'Jones',
//       'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez',
//       'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson',
//       'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin'
//     ];
//     return names[DateTime.now().millisecondsSinceEpoch % names.length];
//   }
// }