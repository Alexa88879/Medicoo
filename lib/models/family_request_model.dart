// lib/models/family_request_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String? requesterPhotoUrl;
  final String receiverId; // UID of the user being invited
  final String receiverEmail; // Email of the user being invited (for initial lookup)
  final String? receiverPatientId; // Patient ID of the user being invited
  final String status; // 'pending', 'accepted', 'declined'
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  FamilyRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    this.requesterPhotoUrl,
    required this.receiverId,
    required this.receiverEmail,
    this.receiverPatientId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory FamilyRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return FamilyRequest(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? '',
      requesterPhotoUrl: data['requesterPhotoUrl'],
      receiverId: data['receiverId'] ?? '',
      receiverEmail: data['receiverEmail'] ?? '',
      receiverPatientId: data['receiverPatientId'],
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requesterId': requesterId,
      'requesterName': requesterName,
      'requesterPhotoUrl': requesterPhotoUrl,
      'receiverId': receiverId,
      'receiverEmail': receiverEmail,
      'receiverPatientId': receiverPatientId,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
  }
}
