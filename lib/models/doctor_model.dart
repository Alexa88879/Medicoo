// lib/models/doctor_model.dart
class Doctor {
  final String uid;
  final String name;
  final String specialization;
  final String? profilePictureUrl;
  final List<dynamic>? qualifications;

  Doctor({
    required this.uid,
    required this.name,
    required this.specialization,
    this.profilePictureUrl,
    this.qualifications,
  });

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