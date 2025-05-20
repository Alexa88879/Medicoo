// lib/screens/account_details_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String? _errorMessage;

  // TextEditingControllers for editable fields
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); // Read-only
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _patientIdController = TextEditingController(); // Read-only

  String? _initialDisplayName;
  String? _initialPhoneNumber;
  String? _initialAge;
  String? _initialBloodGroup;


  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    if (_currentUser != null) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          _displayNameController.text = data['displayName'] ?? '';
          _emailController.text = data['email'] ?? _currentUser!.email ?? '';
          _phoneNumberController.text = data['phoneNumber'] ?? '';
          _ageController.text = data['age']?.toString() ?? '';
          _bloodGroupController.text = data['bloodGroup'] ?? '';
          _patientIdController.text = data['patientId'] ?? 'N/A';

          // Store initial values to check for changes
          _initialDisplayName = _displayNameController.text;
          _initialPhoneNumber = _phoneNumberController.text;
          _initialAge = _ageController.text;
          _initialBloodGroup = _bloodGroupController.text;

        } else {
          _emailController.text = _currentUser!.email ?? '';
          _displayNameController.text = _currentUser!.displayName ?? '';
           _patientIdController.text = 'N/A';
          _errorMessage = "User profile data not found. Some fields may be blank.";
        }
      } catch (e) {
        debugPrint("Error loading user data: $e");
        _errorMessage = "Failed to load profile data.";
      }
    } else {
      _errorMessage = "User not authenticated.";
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool _hasChanges() {
    return _displayNameController.text != _initialDisplayName ||
           _phoneNumberController.text != _initialPhoneNumber ||
           _ageController.text != _initialAge ||
           _bloodGroupController.text != _initialBloodGroup;
  }


  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_hasChanges()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save.')),
      );
      return;
    }


    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    Map<String, dynamic> updatedData = {
      'displayName': _displayNameController.text.trim(),
      'phoneNumber': _phoneNumberController.text.trim().isEmpty ? null : _phoneNumberController.text.trim(),
      'age': _ageController.text.trim().isEmpty ? null : int.tryParse(_ageController.text.trim()),
      'bloodGroup': _bloodGroupController.text.trim().isEmpty ? null : _bloodGroupController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Remove null values to avoid overwriting existing fields with null if not edited
    updatedData.removeWhere((key, value) => value == null && key != 'phoneNumber' && key != 'age' && key != 'bloodGroup');


    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update(updatedData);
      
      // Update Firebase Auth display name if it changed
      if (_currentUser!.displayName != _displayNameController.text.trim()) {
        await _currentUser!.updateDisplayName(_displayNameController.text.trim());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        // Update initial values to reflect saved changes
        _initialDisplayName = _displayNameController.text;
        _initialPhoneNumber = _phoneNumberController.text;
        _initialAge = _ageController.text;
        _initialBloodGroup = _bloodGroupController.text;
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _ageController.dispose();
    _bloodGroupController.dispose();
    _patientIdController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    String? Function(String?)? validator,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: Theme.of(context).primaryColor) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: readOnly,
          fillColor: readOnly ? Colors.grey[200] : null,
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Details', style: TextStyle(color: Color(0xFF00695C))),
        backgroundColor: Colors.white,
        elevation: 1.0,
        iconTheme: const IconThemeData(color: Color(0xFF00695C)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? Center(child: Text(_errorMessage ?? 'User not logged in.', style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null && !_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                          ),
                        Center(
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: _currentUser!.photoURL != null
                                ? NetworkImage(_currentUser!.photoURL!)
                                : null,
                            child: _currentUser!.photoURL == null
                                ? Icon(Icons.person, size: 50, color: Colors.grey.shade600)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _displayNameController,
                          label: 'Full Name',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          icon: Icons.email_outlined,
                          readOnly: true,
                        ),
                        _buildTextField(
                          controller: _patientIdController,
                          label: 'Patient ID',
                          icon: Icons.badge_outlined,
                          readOnly: true,
                        ),
                        _buildTextField(
                          controller: _phoneNumberController,
                          label: 'Phone Number (Optional)',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        _buildTextField(
                          controller: _ageController,
                          label: 'Age (Optional)',
                          icon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                           validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final age = int.tryParse(value);
                              if (age == null || age <= 0 || age > 120) {
                                return 'Please enter a valid age';
                              }
                            }
                            return null;
                          },
                        ),
                        _buildTextField(
                          controller: _bloodGroupController,
                          label: 'Blood Group (Optional)',
                          icon: Icons.bloodtype_outlined,
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : const Text('Save Changes', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
