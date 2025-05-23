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

  final TextEditingController _patientIdController = TextEditingController();
  bool _isSearching = false;
  bool _isLoadingRequest = false;
  Map<String, dynamic>? _searchedUser;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  Future<void> _searchUserByPatientId() async {
    if (_patientIdController.text.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchError = "Please enter a Patient ID.";
        _searchedUser = null;
      });
      return;
    }
    
    if (_currentUser == null) {
      if (!mounted) return;
       setState(() {
        _searchError = "User not logged in. Please restart the app.";
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchedUser = null;
    });

    try {
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('patientId', isEqualTo: _patientIdController.text.trim().toUpperCase()) // Search by patientId, consider making it case-insensitive if needed or store patientId consistently
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final foundUserDoc = userQuery.docs.first;
        final foundUserData = foundUserDoc.data() as Map<String, dynamic>?;

        if (foundUserDoc.id == _currentUser!.uid) {
          if (!mounted) return;
          setState(() {
            _searchError = "You cannot add yourself as a family member.";
            _searchedUser = null;
            _isSearching = false;
          });
          return;
        }

        // Check if already a family member
        DocumentSnapshot currentUserDocSnapshot = await _firestore.collection('users').doc(_currentUser!.uid).get();
        final currentUserData = currentUserDocSnapshot.data() as Map<String, dynamic>?;
        List<dynamic> familyMemberIds = currentUserData?['familyMemberIds'] ?? [];

        if (familyMemberIds.contains(foundUserDoc.id)) {
          if (!mounted) return;
          setState(() {
            _searchError = "${foundUserData?['displayName'] ?? 'This user'} is already a family member.";
            _searchedUser = null;
            _isSearching = false;
          });
          return;
        }

        // Check for existing pending requests (either direction)
        QuerySnapshot existingRequestQuery = await _firestore.collection('family_requests')
            .where('status', isEqualTo: 'pending')
            .where(
              Filter.or(
                Filter.and(Filter('requesterId', isEqualTo: _currentUser!.uid), Filter('receiverId', isEqualTo: foundUserDoc.id)),
                Filter.and(Filter('requesterId', isEqualTo: foundUserDoc.id), Filter('receiverId', isEqualTo: _currentUser!.uid))
              )
            ).limit(1).get();

        if(existingRequestQuery.docs.isNotEmpty){
           if (!mounted) return;
           setState(() {
            _searchError = "A family request is already pending with this user.";
            _searchedUser = null;
            _isSearching = false;
          });
          return;
        }
        
        if (!mounted) return;
        if (foundUserData != null) {
          setState(() {
            _searchedUser = {
              'uid': foundUserDoc.id,
              'displayName': foundUserData['displayName'],
              'email': foundUserData['email'], 
              'photoURL': foundUserData['photoURL'],
              'patientId': foundUserData['patientId'],
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
        if (!mounted) return;
        setState(() {
          _searchError = "No user found with this Patient ID.";
          _searchedUser = null;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint("Error searching user by Patient ID: $e");
      if (!mounted) return;
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

    if (!mounted) return;
    setState(() => _isLoadingRequest = true);

    try {
      // Double-check for existing pending request before sending
      QuerySnapshot existingRequestQuery = await _firestore.collection('family_requests')
            .where('status', isEqualTo: 'pending')
            .where(
              Filter.or(
                Filter.and(Filter('requesterId', isEqualTo: _currentUser!.uid), Filter('receiverId', isEqualTo: _searchedUser!['uid'])),
                Filter.and(Filter('requesterId', isEqualTo: _searchedUser!['uid']), Filter('receiverId', isEqualTo: _currentUser!.uid))
              )
            ).limit(1).get();

      if(existingRequestQuery.docs.isNotEmpty){
           if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A request with this user is already pending.'), backgroundColor: Colors.orange),
          );
           setState(() => _isLoadingRequest = false);
          return;
      }

      DocumentReference requestRef = _firestore.collection('family_requests').doc();
      Map<String, dynamic> requestData = {
        'requesterId': _currentUser!.uid,
        'requesterName': _currentUser!.displayName ?? _currentUser!.email, // Fallback to email if display name is null
        'requesterPhotoUrl': _currentUser!.photoURL,
        'receiverId': _searchedUser!['uid'],
        'receiverEmail': _searchedUser!['email'], 
        'receiverPatientId': _searchedUser!['patientId'], 
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await requestRef.set(requestData);
      
      if (!mounted) return;
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
      if (!mounted) return;
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
              'Enter the Patient ID of the user you want to add as a family member.',
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _patientIdController,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters, // For Patient ID
              decoration: InputDecoration(
                labelText: 'Patient ID',
                hintText: 'E.g., PATIENT123',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.badge_outlined),
                suffixIcon: _isSearching 
                    ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3)))
                    : IconButton(icon: const Icon(Icons.search), onPressed: _searchUserByPatientId),
              ),
              onSubmitted: (_) => _searchUserByPatientId(),
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
                    backgroundImage: _searchedUser!['photoURL'] != null && _searchedUser!['photoURL'].isNotEmpty
                        ? NetworkImage(_searchedUser!['photoURL'])
                        : null,
                    child: _searchedUser!['photoURL'] == null || _searchedUser!['photoURL'].isEmpty 
                        ? const Icon(Icons.person) 
                        : null,
                  ),
                  title: Text(_searchedUser!['displayName'] ?? 'N/A'),
                  subtitle: Text("Patient ID: ${_searchedUser!['patientId'] ?? 'N/A'}"),
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
    _patientIdController.dispose();
    super.dispose();
  }
}
