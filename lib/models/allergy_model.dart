// lib/models/allergy_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Allergy {
  final String id;
  final String userId;
  final String allergyType;
  final String allergyName;
  final String reactionType;
  final String severity;
  final String medication;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  Allergy({
    required this.id,
    required this.userId,
    required this.allergyType,
    required this.allergyName,
    required this.reactionType,
    required this.severity,
    required this.medication,
    required this.createdAt,
    this.updatedAt,
  });

  factory Allergy.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return Allergy(
      id: doc.id,
      userId: data['userId'] ?? '',
      allergyType: data['allergyType'] ?? '',
      allergyName: data['allergyName'] ?? '',
      reactionType: data['reactionType'] ?? '',
      severity: data['severity'] ?? '',
      medication: data['medication'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'allergyType': allergyType,
      'allergyName': allergyName,
      'reactionType': reactionType,
      'severity': severity,
      'medication': medication,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(), // Set on update
    };
  }
}
