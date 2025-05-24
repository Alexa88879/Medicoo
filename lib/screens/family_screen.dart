// lib/screens/family_screen.dart
import 'dart:async'; // Required for StreamTransformer

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_family_member_screen.dart';
import '../models/family_request_model.dart';
import '../models/allergy_model.dart'; // Import the Allergy model

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

  Stream<List<Map<String, dynamic>>> _getFamilyMembersStream() {
    if (_currentUser == null) return Stream.value([]);
    
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
            final data = memberDoc.data() as Map<String, dynamic>;
            membersData.add({
              'uid': memberDoc.id,
              'displayName': data['displayName'] ?? 'N/A',
              'photoURL': data['photoURL'],
              'patientId': data['patientId'] ?? 'N/A',
            });
          }
        } catch (e) {
          debugPrint("Error fetching family member $memberId: $e");
          // Optionally, rethrow or handle more gracefully
        }
      }
      return membersData;
    });
  }

  // Stream to get allergies for a specific family member
  Stream<List<Allergy>> _getFamilyMemberAllergiesStream(String memberId) {
    // IMPORTANT: This stream will fail with permission errors if Firebase rules are not updated.
    return _firestore
        .collection('user_allergies')
        .where('userId', isEqualTo: memberId)
        .orderBy('createdAt', descending: true)
        .snapshots() // Stream<QuerySnapshot<Map<String, dynamic>>>
        .map<List<Allergy>>((snapshot) { // Explicitly type the map's output
          // This map function transforms QuerySnapshot to List<Allergy>
          if (snapshot.docs.isEmpty) {
            return <Allergy>[]; // Return an empty list of the correct type
          }
          try {
            return snapshot.docs
                .map<Allergy>((doc) => Allergy.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)) // Explicitly type this map
                .toList();
          } catch(e) {
            // This catch is for errors during the parsing of individual documents
            debugPrint("Error parsing individual allergy doc for $memberId within map: $e");
            // If one document fails to parse, you might decide to return an empty list for the whole snapshot,
            // or filter out the problematic document. For simplicity, returning empty here.
            return <Allergy>[]; 
          }
        }) // Output of this map: Stream<List<Allergy>>
        .transform(StreamTransformer<List<Allergy>, List<Allergy>>.fromHandlers(
          handleError: (Object error, StackTrace stackTrace, EventSink<List<Allergy>> sink) {
            // This handles errors from the stream itself (e.g., Firestore permission errors)
            // or errors rethrown from the .map() operation.
            debugPrint("Error in _getFamilyMemberAllergiesStream for $memberId (transformed): $error");
            // debugPrintStack(stackTrace: stackTrace); // Uncomment for full stack trace
            sink.add(<Allergy>[]); // Emit an empty list of the correct type on error
            // sink.close(); // Do not close the sink if the original stream is a snapshot stream that might emit further events or recover.
                           // For Firestore snapshots, an error like permission denied is often persistent for that query.
          },
        ));
  }

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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request not found.')));
        return;
      }

      FamilyRequest request = FamilyRequest.fromFirestore(requestDoc as DocumentSnapshot<Map<String, dynamic>>);

      await _firestore.runTransaction((transaction) async {
        transaction.update(requestRef, {
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (newStatus == 'accepted') {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request ${newStatus == "accepted" ? "accepted" : "declined"}.')),
      );
    } catch (e) {
      debugPrint("Error updating request: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: ${e.toString()}')),
      );
    }
  }
  
  Future<void> _cancelOutgoingRequest(String requestId) async {
    if (!mounted) return;
    final bool? confirmCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Request'),
          content: const Text('Are you sure you want to cancel this family request?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Yes, Cancel', style: TextStyle(color: Colors.orange)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmCancel == true) {
      try {
        await _firestore.collection('family_requests').doc(requestId).delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel request: ${e.toString()}')),
        );
      }
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
         if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Family member removed.')),
        );
      } catch (e) {
        debugPrint("Error removing family member: $e");
        if (!mounted) return;
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
    final String memberUid = memberData['uid'];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundImage: memberData['photoURL'] != null && memberData['photoURL'].isNotEmpty 
              ? NetworkImage(memberData['photoURL']) 
              : null,
          child: memberData['photoURL'] == null || memberData['photoURL'].isEmpty 
              ? const Icon(Icons.person_outline) 
              : null,
        ),
        title: Text(memberData['displayName'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text("Patient ID: ${memberData['patientId'] ?? 'N/A'}"),
        trailing: IconButton( 
          icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
          tooltip: "Remove Member",
          onPressed: () => _removeFamilyMember(memberUid),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: StreamBuilder<List<Allergy>>(
              stream: _getFamilyMemberAllergiesStream(memberUid),
              builder: (context, allergySnapshot) {
                if (allergySnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2,))));
                }
                if (allergySnapshot.hasError) {
                  return Text('Could not load allergies. (Check Permissions)', style: TextStyle(color: Colors.orange.shade800));
                }
                if (!allergySnapshot.hasData || allergySnapshot.data!.isEmpty) {
                  return const Text('No allergies recorded for this member.', style: TextStyle(color: Colors.grey));
                }
                final allergies = allergySnapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Allergies:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (allergies.isEmpty)
                      const Text("None listed.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                    ...allergies.map((allergy) => Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        "- ${allergy.allergyName} (Severity: ${allergy.severity}, Reaction: ${allergy.reactionType})",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    )).toList(),
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildRequestListTile(FamilyRequest request, bool isIncoming) {
    String titleText = isIncoming 
        ? request.requesterName 
        : "To: ${request.receiverPatientId ?? request.receiverEmail}";
    String subtitleText = isIncoming 
        ? "${request.requesterName} wants to add you as family." 
        : "Status: ${request.status.toUpperCase()} (Sent: ${DateFormat('dd MMM yy').format(request.createdAt.toDate())})";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: request.requesterPhotoUrl != null && request.requesterPhotoUrl!.isNotEmpty 
              ? NetworkImage(request.requesterPhotoUrl!) 
              : null,
          child: request.requesterPhotoUrl == null || request.requesterPhotoUrl!.isEmpty 
              ? const Icon(Icons.person_outline) 
              : null,
        ),
        title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitleText),
        trailing: isIncoming
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 28),
                    tooltip: "Accept",
                    onPressed: () => _updateRequestStatus(request.id, 'accepted'),
                  ),
                  IconButton(
                    icon: Icon(Icons.cancel_outlined, color: Colors.red.shade400, size: 28),
                    tooltip: "Decline",
                    onPressed: () => _updateRequestStatus(request.id, 'declined'),
                  ),
                ],
              )
            : (request.status == 'pending' 
                ? IconButton(
                    icon: Icon(Icons.cancel_schedule_send_outlined, color: Colors.orange.shade700, size: 28),
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
          : RefreshIndicator(
              onRefresh: () async {
                if(mounted) setState(() {});
              },
              color: Theme.of(context).primaryColor,
              child: ListView(
                children: [
                  _buildSectionTitle('My Family Members'),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _getFamilyMembersStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error: ${snapshot.error}")));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                          child: Center(child: Text('No family members added yet.', style: TextStyle(color: Colors.grey))),
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
                        return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                      }
                       if (snapshot.hasError) {
                        return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error: ${snapshot.error}")));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                          child: Center(child: Text('No incoming requests.', style: TextStyle(color: Colors.grey))),
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
                        return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                      }
                       if (snapshot.hasError) {
                        return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error: ${snapshot.error}")));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                          child: Center(child: Text('No pending outgoing requests.', style: TextStyle(color: Colors.grey))),
                        );
                      }
                      return Column(children: snapshot.data!.map((req) => _buildRequestListTile(req, false)).toList());
                    },
                  ),
                  const SizedBox(height: 80), 
                ],
              ),
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
