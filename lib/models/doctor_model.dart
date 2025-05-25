// lib/models/doctor_model.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Required for GeoPoint if you use it

class Doctor {
  final String uid;
  final String name; // Corresponds to 'name' in Firestore (was displayName in image)
  final String? email;
  final String? phoneNumber;
  final String? imageUrl; // Corresponds to 'imageUrl' in Firestore (profile picture)
  final String? bio; // Corresponds to 'bio' in Firestore (was 'about' in image)
  final String specialization; // Corresponds to 'speciality' in Firestore (was 'specialization' in image)
  final List<String>? qualifications; // Corresponds to 'qualifications' in Firestore
  final int? yearsOfExperience; // Corresponds to 'yearsOfExperience' in Firestore
  final double? consultationFee; // Corresponds to 'consultationFee' in Firestore
  final bool? isAvailable; // Corresponds to 'isAvailable' in Firestore (was 'isActive' in image)
  final Map<String, List<String>>? availableSlots; // E.g., {"monday": ["09:00", "10:00"]}
  final String? licenseNumber;
  final List<String>? hospitalAffiliations;
  final double? rating;
  final int? totalRatings;
  final String? role; // Should be "doctor"
  final String? address;
  final GeoPoint? location; // Firestore GeoPoint
  final List<String>? servicesOffered;
  final List<String>? languagesSpoken;
  final bool? offersVideoConsultation; // Added for video consultation

  Doctor({
    required this.uid,
    required this.name,
    this.email,
    this.phoneNumber,
    this.imageUrl,
    this.bio,
    required this.specialization,
    this.qualifications,
    this.yearsOfExperience,
    this.consultationFee,
    this.isAvailable,
    this.availableSlots,
    this.licenseNumber,
    this.hospitalAffiliations,
    this.rating,
    this.totalRatings,
    this.role,
    this.address,
    this.location,
    this.servicesOffered,
    this.languagesSpoken,
    this.offersVideoConsultation,
  });

  factory Doctor.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    
    List<String>? qualificationsList;
    if (data['qualifications'] != null) {
      if (data['qualifications'] is String) {
        qualificationsList = (data['qualifications'] as String)
            .split(',')
            .map((q) => q.trim())
            .where((q) => q.isNotEmpty)
            .toList();
      } else if (data['qualifications'] is List) {
        qualificationsList = List<String>.from(data['qualifications']);
      }
    }

    List<String>? hospitalAffiliationsList;
    if (data['hospitalAffiliations'] != null && data['hospitalAffiliations'] is List) {
      hospitalAffiliationsList = List<String>.from(data['hospitalAffiliations']);
    }

    List<String>? servicesOfferedList;
    if (data['servicesOffered'] != null && data['servicesOffered'] is List) {
      servicesOfferedList = List<String>.from(data['servicesOffered']);
    }
    
    List<String>? languagesSpokenList;
    if (data['languagesSpoken'] != null && data['languagesSpoken'] is List) {
      languagesSpokenList = List<String>.from(data['languagesSpoken']);
    }

    Map<String, List<String>>? slots;
    if (data['availableSlots'] is Map) {
      slots = (data['availableSlots'] as Map).map((key, value) {
        if (value is List) {
          return MapEntry(key as String, List<String>.from(value));
        }
        return MapEntry(key as String, <String>[]); // Fallback for malformed slot data
      });
    }

    return Doctor(
      uid: doc.id,
      name: data['name'] ?? 'N/A', // Firestore field: name
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      imageUrl: data['imageUrl'],
      bio: data['bio'], // Firestore field: bio
      specialization: data['speciality'] ?? 'N/A', // Firestore field: speciality
      qualifications: qualificationsList,
      yearsOfExperience: (data['yearsOfExperience'] as num?)?.toInt(),
      consultationFee: (data['consultationFee'] as num?)?.toDouble(),
      isAvailable: data['isAvailable'], // Firestore field: isAvailable
      availableSlots: slots,
      licenseNumber: data['licenseNumber'],
      hospitalAffiliations: hospitalAffiliationsList,
      rating: (data['rating'] as num?)?.toDouble(),
      totalRatings: (data['totalRatings'] as num?)?.toInt(),
      role: data['role'],
      address: data['address'],
      location: data['location'] as GeoPoint?,
      servicesOffered: servicesOfferedList,
      languagesSpoken: languagesSpokenList,
      offersVideoConsultation: data['offersVideoConsultation'] ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Doctor && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() {
    return '$name ($specialization)';
  }
}
