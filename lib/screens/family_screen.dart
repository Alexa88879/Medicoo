// lib/screens/family_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_family_member_screen.dart';
import '../models/family_request_model.dart';
// You might create a simple User model for displaying family members or use a Map
// For now, we'll fetch basic info directly.

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  // Stream to get accepted family members
  Stream<List<Map<String, dynamic>>> _getFamilyMembersStream() {
    if (_currentUser == null) return Stream.value([]);
    // This assumes you have a 'familyMembers' array in your user document
    // containing UIDs of accepted family members.
    // Or, a more complex query if you use a separate 'families' collection.
    // For now, let's assume 'familyMembers' array in 'users' doc.
    return _firestore.collection('users').doc(_currentUser!.uid).snapshots().asyncMap((userDoc) async {
      if (!userDoc.exists || userDoc.data()?['familyMemberIds'] == null) {
        return [];
      }
      List<String> memberIds = List<String>.from(userDoc.data()!['familyMemberIds']);
      if (memberIds.isEmpty) return [];

      List<Map<String, dynamic>> membersData = [];
      for (String memberId in memberIds) {
        try {
          DocumentSnapshot memberDoc = await _firestore.collection('users').doc(memberId).get();
          if (memberDoc.exists) {
            membersData.add({
              'uid': memberDoc.id,
              'displayName': (memberDoc.data() as Map<String, dynamic>)?['displayName'] ?? 'N/A',
              'photoURL': (memberDoc.data() as Map<String, dynamic>)?['photoURL'],
            });
          }
        } catch (e) {
          debugPrint("Error fetching family member $memberId: $e");
        }
      }
      return membersData;
    });
  }

  // Stream for incoming family requests
  Stream<List<FamilyRequest>> _getIncomingRequestsStream() {
    if (_currentUser == null) return Stream.value([]);
    return _firestore
        .collection('family_requests')
        .where('receiverId', isEqualTo: _currentUser!.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FamilyRequest.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  // Stream for outgoing family requests
  Stream<List<FamilyRequest>> _getOutgoingRequestsStream() {
    if (_currentUser == null) return Stream.value([]);
    return _firestore
        .collection('family_requests')
        .where('requesterId', isEqualTo: _currentUser!.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FamilyRequest.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    if (_currentUser == null) return;
    try {
      DocumentReference requestRef = _firestore.collection('family_requests').doc(requestId);
      DocumentSnapshot requestDoc = await requestRef.get();

      if (!requestDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request not found.')));
        return;
      }

      FamilyRequest request = FamilyRequest.fromFirestore(requestDoc as DocumentSnapshot<Map<String, dynamic>>);

      await _firestore.runTransaction((transaction) async {
        // Update the request status
        transaction.update(requestRef, {
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (newStatus == 'accepted') {
          // Add to each other's familyMemberIds list
          DocumentReference currentUserRef = _firestore.collection('users').doc(_currentUser!.uid);
          DocumentReference requesterUserRef = _firestore.collection('users').doc(request.requesterId);

          transaction.update(currentUserRef, {
            'familyMemberIds': FieldValue.arrayUnion([request.requesterId])
          });
          transaction.update(requesterUserRef, {
            'familyMemberIds': FieldValue.arrayUnion([_currentUser!.uid])
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request ${newStatus == "accepted" ? "accepted" : "declined"}.')),
      );
    } catch (e) {
      debugPrint("Error updating request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: ${e.toString()}')),
      );
    }
  }
  
  Future<void> _cancelOutgoingRequest(String requestId) async {
    // Optional: Add confirmation dialog
    try {
      await _firestore.collection('family_requests').doc(requestId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request cancelled.')),
      );
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel request: ${e.toString()}')),
      );
    }
  }

  Future<void> _removeFamilyMember(String memberIdToRemove) async {
    if (_currentUser == null) return;

    final bool? confirmRemove = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Remove Family Member'),
          content: const Text('Are you sure you want to remove this family member? This will remove them from your list and you from theirs.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmRemove == true) {
      try {
        await _firestore.runTransaction((transaction) async {
          DocumentReference currentUserRef = _firestore.collection('users').doc(_currentUser!.uid);
          DocumentReference memberUserRef = _firestore.collection('users').doc(memberIdToRemove);

          transaction.update(currentUserRef, {
            'familyMemberIds': FieldValue.arrayRemove([memberIdToRemove])
          });
          transaction.update(memberUserRef, {
            'familyMemberIds': FieldValue.arrayRemove([_currentUser!.uid])
          });
        });
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Family member removed.')),
        );
      } catch (e) {
        debugPrint("Error removing family member: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove family member: ${e.toString()}')),
        );
      }
    }
  }


  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0, left: 16, right: 16),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
      ),
    );
  }

  Widget _buildFamilyMemberListTile(Map<String, dynamic> memberData) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: memberData['photoURL'] != null ? NetworkImage(memberData['photoURL']) : null,
          child: memberData['photoURL'] == null ? const Icon(Icons.person) : null,
        ),
        title: Text(memberData['displayName'] ?? 'N/A'),
        trailing: IconButton(
          icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
          onPressed: () => _removeFamilyMember(memberData['uid']),
        ),
      ),
    );
  }
  
  Widget _buildRequestListTile(FamilyRequest request, bool isIncoming) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: request.requesterPhotoUrl != null ? NetworkImage(request.requesterPhotoUrl!) : null,
          child: request.requesterPhotoUrl == null ? const Icon(Icons.person_outline) : null,
        ),
        title: Text(isIncoming ? request.requesterName : "To: ${request.receiverEmail}"),
        subtitle: Text(isIncoming ? "${request.requesterName} wants to add you as family." : "Status: ${request.status}"),
        trailing: isIncoming
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.check_circle_outline, color: Colors.green.shade600),
                    onPressed: () => _updateRequestStatus(request.id, 'accepted'),
                  ),
                  IconButton(
                    icon: Icon(Icons.cancel_outlined, color: Colors.red.shade400),
                    onPressed: () => _updateRequestStatus(request.id, 'declined'),
                  ),
                ],
              )
            : (request.status == 'pending' 
                ? IconButton(
                    icon: Icon(Icons.cancel_schedule_send_outlined, color: Colors.orange.shade700),
                    tooltip: "Cancel Request",
                    onPressed: () => _cancelOutgoingRequest(request.id),
                  )
                : null
              ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Members', style: TextStyle(color: Color(0xFF00695C))),
        backgroundColor: Colors.white,
        elevation: 1.0,
        iconTheme: const IconThemeData(color: Color(0xFF00695C)),
      ),
      body: _currentUser == null
          ? const Center(child: Text("Please log in to view family members."))
          : ListView(
              children: [
                _buildSectionTitle('My Family Members'),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _getFamilyMembersStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        child: Text('No family members added yet.', style: TextStyle(color: Colors.grey)),
                      );
                    }
                    return Column(children: snapshot.data!.map(_buildFamilyMemberListTile).toList());
                  },
                ),

                _buildSectionTitle('Incoming Requests'),
                StreamBuilder<List<FamilyRequest>>(
                  stream: _getIncomingRequestsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        child: Text('No incoming requests.', style: TextStyle(color: Colors.grey)),
                      );
                    }
                    return Column(children: snapshot.data!.map((req) => _buildRequestListTile(req, true)).toList());
                  },
                ),

                _buildSectionTitle('Outgoing Requests'),
                 StreamBuilder<List<FamilyRequest>>(
                  stream: _getOutgoingRequestsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        child: Text('No pending outgoing requests.', style: TextStyle(color: Colors.grey)),
                      );
                    }
                    return Column(children: snapshot.data!.map((req) => _buildRequestListTile(req, false)).toList());
                  },
                ),
                const SizedBox(height: 80), // Space for FAB
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFamilyMemberScreen()),
          );
        },
        label: const Text('Add Member'),
        icon: const Icon(Icons.group_add_outlined),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
