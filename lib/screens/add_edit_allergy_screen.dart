// lib/screens/add_edit_allergy_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/allergy_model.dart';

class AddEditAllergyScreen extends StatefulWidget {
  final Allergy? allergyToEdit;
  final bool isReadOnly; // To view details without editing

  const AddEditAllergyScreen({super.key, this.allergyToEdit, this.isReadOnly = false});

  @override
  State<AddEditAllergyScreen> createState() => _AddEditAllergyScreenState();
}

class _AddEditAllergyScreenState extends State<AddEditAllergyScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TextEditingController _allergyNameController;
  late TextEditingController _medicationController;

  bool _isLoading = false;

  // Example dropdown items - you might want to fetch these or make them configurable
  final List<String> _allergyTypes = ['Food', 'Medication', 'Environmental', 'Insect Sting', 'Latex', 'Other'];
  final List<String> _severities = ['Mild', 'Moderate', 'Severe', 'Life-threatening'];
  final List<String> _reactionTypes = ['Skin Rash/Hives', 'Swelling (Angioedema)', 'Itching', 'Difficulty Breathing', 'Anaphylaxis', 'Nausea/Vomiting', 'Diarrhea', 'Headache', 'Dizziness', 'Other'];

  String? _selectedAllergyType;
  String? _selectedSeverity;
  String? _selectedReactionType;


  @override
  void initState() {
    super.initState();
    _allergyNameController = TextEditingController(text: widget.allergyToEdit?.allergyName);
    _medicationController = TextEditingController(text: widget.allergyToEdit?.medication);

    if (widget.allergyToEdit != null) {
        _selectedAllergyType = _allergyTypes.contains(widget.allergyToEdit!.allergyType) ? widget.allergyToEdit!.allergyType : null;
        _selectedSeverity = _severities.contains(widget.allergyToEdit!.severity) ? widget.allergyToEdit!.severity : null;
        _selectedReactionType = _reactionTypes.contains(widget.allergyToEdit!.reactionType) ? widget.allergyToEdit!.reactionType : null;
    }
  }

  @override
  void dispose() {
    _allergyNameController.dispose();
    _medicationController.dispose();
    super.dispose();
  }

  Future<void> _saveAllergy() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedAllergyType == null || _selectedReactionType == null || _selectedSeverity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Please make a selection for all dropdown fields.')),
        );
        return;
    }


    setState(() => _isLoading = true);

    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    Map<String, dynamic> allergyData = {
      'userId': currentUser.uid,
      'allergyType': _selectedAllergyType!,
      'allergyName': _allergyNameController.text.trim(),
      'reactionType': _selectedReactionType!,
      'severity': _selectedSeverity!,
      'medication': _medicationController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.allergyToEdit == null) { // Add new allergy
        allergyData['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('user_allergies').add(allergyData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Allergy added successfully!')),
          );
        }
      } else { // Update existing allergy
        await _firestore.collection('user_allergies').doc(widget.allergyToEdit!.id).update(allergyData);
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Allergy updated successfully!')),
          );
         }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save allergy: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDropdownField({
    required String label,
    required String? currentValue,
    required List<String> items,
    ValueChanged<String?>? onChangedFromCaller, // Renamed for clarity
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.0),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: readOnly || onChangedFromCaller == null
            ? null 
            : (String? newValue) { 
                onChangedFromCaller(newValue);
              },
        decoration: InputDecoration(
          hintText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          filled: true, 
          fillColor: readOnly ? Colors.grey[200] : Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        ),
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
    );
  }


  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          filled: true, 
          fillColor: readOnly ? Colors.grey[200] : Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        ),
        validator: validator,
         autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    String appBarTitle = widget.isReadOnly
        ? 'Allergy Details'
        : widget.allergyToEdit == null
            ? 'Add New Allergy'
            : 'Edit Allergy';
    
    final TextStyle labelStyle = TextStyle(
      color: Theme.of(context).primaryColor, 
      fontWeight: FontWeight.w600,
      fontSize: 16,
    );


    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(color: Color(0xFF00695C))),
        backgroundColor: Colors.white,
        elevation: 1.0,
        iconTheme: const IconThemeData(color: Color(0xFF00695C)),
        actions: [
          if (!widget.isReadOnly)
            IconButton(
              icon: Icon(Icons.save_outlined, color: _isLoading ? Colors.grey : const Color(0xFF00695C)),
              onPressed: _isLoading ? null : _saveAllergy,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text('Allergy Type*', style: labelStyle),
                    const SizedBox(height: 8),
                    _buildDropdownField(
                      label: 'Type', 
                      currentValue: _selectedAllergyType,
                      items: _allergyTypes,
                      onChangedFromCaller: widget.isReadOnly // Changed parameter name
                          ? null 
                          : (String? newValue) {
                              setState(() => _selectedAllergyType = newValue);
                            },
                      validator: (value) => value == null || value.isEmpty ? 'Please select allergy type' : null,
                      readOnly: widget.isReadOnly,
                    ),
                    const SizedBox(height: 16),
                    Text('Allergy Name*', style: labelStyle),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _allergyNameController,
                      label: 'Name', 
                      readOnly: widget.isReadOnly,
                      validator: (value) => value == null || value.trim().isEmpty ? 'Please enter allergy name' : null,
                    ),
                    const SizedBox(height: 16),
                    Text('Reaction Type*', style: labelStyle),
                    const SizedBox(height: 8),
                     _buildDropdownField(
                      label: 'Type', 
                      currentValue: _selectedReactionType,
                      items: _reactionTypes,
                      onChangedFromCaller: widget.isReadOnly // Changed parameter name
                          ? null 
                          : (String? newValue) {
                              setState(() => _selectedReactionType = newValue);
                            },
                      validator: (value) => value == null || value.isEmpty ? 'Please select reaction type' : null,
                      readOnly: widget.isReadOnly,
                    ),
                    const SizedBox(height: 16),
                    Text('Severity*', style: labelStyle),
                    const SizedBox(height: 8),
                    _buildDropdownField(
                      label: 'Severity', 
                      currentValue: _selectedSeverity,
                      items: _severities,
                      onChangedFromCaller: widget.isReadOnly // Changed parameter name
                          ? null 
                          : (String? newValue) {
                              setState(() => _selectedSeverity = newValue);
                            },
                      validator: (value) => value == null || value.isEmpty ? 'Please select severity' : null,
                      readOnly: widget.isReadOnly,
                    ),
                    const SizedBox(height: 16),
                    Text('Medication / Treatment', style: labelStyle),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _medicationController,
                      label: 'Treatment', 
                      readOnly: widget.isReadOnly,
                    ),
                    const SizedBox(height: 30),
                    if (!widget.isReadOnly)
                      SizedBox( 
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveAllergy,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          child: Text(widget.allergyToEdit == null ? 'Add Allergy' : 'Save Changes'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
