// lib/screens/add_family_member_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddFamilyMemberScreen extends StatefulWidget {
  const AddFamilyMemberScreen({super.key});

  @override
  State<AddFamilyMemberScreen> createState() => _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  final TextEditingController _patientIdController = TextEditingController(); // Changed from _emailController
  bool _isSearching = false;
  bool _isLoadingRequest = false;
  Map<String, dynamic>? _searchedUser;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  Future<void> _searchUserByPatientId() async { // Renamed function
    if (_patientIdController.text.trim().isEmpty) {
      setState(() {
        _searchError = "Please enter a Patient ID.";
        _searchedUser = null;
      });
      return;
    }
    
    // It's good practice to prevent searching for one's own patient ID if applicable,
    // but a user might not know their own patient ID easily.
    // We'll rely on not being able to send a request to oneself later.

    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchedUser = null;
    });

    try {
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('patientId', isEqualTo: _patientIdController.text.trim()) // Search by patientId
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final foundUserDoc = userQuery.docs.first;
        final foundUserData = foundUserDoc.data() as Map<String, dynamic>?;

        if (foundUserDoc.id == _currentUser!.uid) {
          setState(() {
            _searchError = "You cannot add yourself as a family member.";
            _searchedUser = null;
            _isSearching = false;
          });
          return;
        }

        DocumentSnapshot currentUserDocSnapshot = await _firestore.collection('users').doc(_currentUser!.uid).get();
        final currentUserData = currentUserDocSnapshot.data() as Map<String, dynamic>?;
        List<dynamic> familyMemberIds = currentUserData?['familyMemberIds'] ?? [];

        if (familyMemberIds.contains(foundUserDoc.id)) {
          setState(() {
            _searchError = "${foundUserData?['displayName'] ?? 'This user'} is already a family member.";
            _searchedUser = null;
            _isSearching = false;
          });
          return;
        }

        QuerySnapshot existingRequestQuery = await _firestore.collection('family_requests')
            .where('status', isEqualTo: 'pending')
            .where(Filter.or(
                Filter.and(Filter('requesterId', isEqualTo: _currentUser!.uid), Filter('receiverId', isEqualTo: foundUserDoc.id)),
                Filter.and(Filter('requesterId', isEqualTo: foundUserDoc.id), Filter('receiverId', isEqualTo: _currentUser!.uid))
            )).limit(1).get();

        if(existingRequestQuery.docs.isNotEmpty){
           setState(() {
            _searchError = "A family request is already pending with this user.";
            _searchedUser = null;
            _isSearching = false;
          });
          return;
        }

        if (foundUserData != null) {
          setState(() {
            _searchedUser = {
              'uid': foundUserDoc.id,
              'displayName': foundUserData['displayName'],
              'email': foundUserData['email'], // Keep email for display/request if needed
              'photoURL': foundUserData['photoURL'],
              'patientId': foundUserData['patientId'], // Include patientId
            };
            _isSearching = false;
          });
        } else {
           setState(() {
            _searchError = "User data is not in the expected format.";
            _searchedUser = null;
            _isSearching = false;
          });
        }
      } else {
        setState(() {
          _searchError = "No user found with this Patient ID.";
          _searchedUser = null;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint("Error searching user by Patient ID: $e");
      if (e is FirebaseException && e.code == 'permission-denied') {
        _searchError = "Permission denied. Please check Firestore rules.";
      } else {
        _searchError = "An error occurred while searching.";
      }
      setState(() {
        _searchedUser = null;
        _isSearching = false;
      });
    }
  }

  Future<void> _sendFamilyRequest() async {
    if (_currentUser == null || _searchedUser == null) return;

    setState(() => _isLoadingRequest = true);

    try {
      QuerySnapshot existingRequestQuery = await _firestore.collection('family_requests')
            .where('status', isEqualTo: 'pending')
            .where(Filter.or(
                Filter.and(Filter('requesterId', isEqualTo: _currentUser!.uid), Filter('receiverId', isEqualTo: _searchedUser!['uid'])),
                Filter.and(Filter('requesterId', isEqualTo: _searchedUser!['uid']), Filter('receiverId', isEqualTo: _currentUser!.uid))
            )).limit(1).get();

      if(existingRequestQuery.docs.isNotEmpty){
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A request with this user is already pending.'), backgroundColor: Colors.orange),
          );
           setState(() => _isLoadingRequest = false);
          return;
      }

      DocumentReference requestRef = _firestore.collection('family_requests').doc();
      Map<String, dynamic> requestData = {
        'requesterId': _currentUser!.uid,
        'requesterName': _currentUser!.displayName ?? _currentUser!.email,
        'requesterPhotoUrl': _currentUser!.photoURL,
        'receiverId': _searchedUser!['uid'],
        'receiverEmail': _searchedUser!['email'], // Still useful to store for context
        'receiverPatientId': _searchedUser!['patientId'], // Store patientId of receiver
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await requestRef.set(requestData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Family request sent to ${_searchedUser!['displayName'] ?? _searchedUser!['patientId']}.')),
      );
      setState(() {
        _searchedUser = null; 
        _patientIdController.clear();
        _isLoadingRequest = false;
      });

    } catch (e) {
      debugPrint("Error sending family request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: ${e.toString()}')),
      );
      setState(() => _isLoadingRequest = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Family Member', style: TextStyle(color: Color(0xFF00695C))),
        backgroundColor: Colors.white,
        elevation: 1.0,
        iconTheme: const IconThemeData(color: Color(0xFF00695C)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the Patient ID of the user you want to add as a family member.', // Updated instruction
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _patientIdController, // Changed controller
              keyboardType: TextInputType.text, // Patient ID can be alphanumeric
              decoration: InputDecoration(
                labelText: 'Patient ID', // Changed label
                hintText: 'E.g., MEDP001', // Changed hint
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.badge_outlined), // Changed icon
                suffixIcon: _isSearching 
                    ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3)))
                    : IconButton(icon: const Icon(Icons.search), onPressed: _searchUserByPatientId), // Call new search function
              ),
              onSubmitted: (_) => _searchUserByPatientId(), // Call new search function
            ),
            if (_searchError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_searchError!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            if (_searchedUser != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: _searchedUser!['photoURL'] != null
                        ? NetworkImage(_searchedUser!['photoURL'])
                        : null,
                    child: _searchedUser!['photoURL'] == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(_searchedUser!['displayName'] ?? 'N/A'),
                  subtitle: Text("Patient ID: ${_searchedUser!['patientId'] ?? 'N/A'}"), // Display Patient ID
                  trailing: ElevatedButton(
                    onPressed: _isLoadingRequest ? null : _sendFamilyRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoadingRequest 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))) 
                        : const Text('Send Request'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _patientIdController.dispose(); // Changed controller
    super.dispose();
  }
}
