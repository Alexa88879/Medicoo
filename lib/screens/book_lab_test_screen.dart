// lib/screens/book_lab_test_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// You might need your NearbyPlaceG model if you integrate lab selection from a map
// import '../models/nearby_place_g_model.dart'; // Assuming you have this

// Simplified model for lab test catalog item for dropdown
class LabTestCatalogItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final bool availableForHomeCollection;
  final bool requiresLabVisit;


  LabTestCatalogItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.availableForHomeCollection,
    required this.requiresLabVisit,
  });

  factory LabTestCatalogItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return LabTestCatalogItem(
      id: doc.id,
      name: data['name'] ?? 'Unknown Test',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? 'Uncategorized',
      availableForHomeCollection: data['availableForHomeCollection'] ?? false,
      requiresLabVisit: data['requiresLabVisit'] ?? true,
    );
  }
}


class BookLabTestScreen extends StatefulWidget {
  const BookLabTestScreen({super.key});

  @override
  State<BookLabTestScreen> createState() => _BookLabTestScreenState();
}

class _BookLabTestScreenState extends State<BookLabTestScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>(); // For potential form validation

  // State variables
  String? _selectedTestCategory;
  List<String> _testCategories = [];
  LabTestCatalogItem? _selectedLabTest;
  List<LabTestCatalogItem> _labTestsForCategory = [];
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _collectionType = 'Lab Visit'; // Default to Lab Visit
  double _amount = 0.0;

  bool _isLoadingCategories = true;
  bool _isLoadingTests = false;
  bool _isBooking = false;
  String? _currentUserName;
  String? _currentUserAddress; // For home collection

  // Example time slots - can be made dynamic or fetched
  final List<String> _timeSlots = [
    '08:00 AM', '08:30 AM', '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM',
    '11:00 AM', '11:30 AM', '12:00 PM', '12:30 PM', '01:00 PM', '01:30 PM',
    '02:00 PM', '02:30 PM', '03:00 PM', '03:30 PM', '04:00 PM', '04:30 PM',
    '05:00 PM', '05:30 PM', '06:00 PM'
  ];
  String? _selectedTimeSlotString;


  @override
  void initState() {
    super.initState();
    _fetchTestCategories();
    _fetchCurrentUserInfo();
    _selectedDate = DateTime.now().add(const Duration(days: 1)); // Default to tomorrow
    _selectedTime = const TimeOfDay(hour: 10, minute: 0); // Default time
    _updateSelectedTimeSlotString();
  }

  Future<void> _fetchCurrentUserInfo() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (mounted && userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserName = data['displayName'] ?? user.displayName;
          _currentUserAddress = data['address']; // Assuming you have an 'address' field in your users collection
        });
      }
    }
  }

  Future<void> _fetchTestCategories() async {
    if (!mounted) return;
    setState(() => _isLoadingCategories = true);
    try {
      QuerySnapshot categorySnapshot = await _firestore.collection('lab_test_categories').orderBy('name').get();
      if (mounted) {
        setState(() {
          _testCategories = categorySnapshot.docs.map((doc) => doc['name'] as String).toList();
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching lab test categories: $e");
      if (mounted) {
        setState(() => _isLoadingCategories = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading test categories: ${e.toString()}'))
        );
      }
    }
  }

  Future<void> _fetchLabTestsForCategory(String category) async {
    if (!mounted) return;
    setState(() {
      _isLoadingTests = true;
      _labTestsForCategory = [];
      _selectedLabTest = null; // Reset selected test
      _amount = 0.0;
    });
    try {
      QuerySnapshot testSnapshot = await _firestore
          .collection('lab_test_catalog')
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true) // Only fetch active tests
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _labTestsForCategory = testSnapshot.docs
              .map((doc) => LabTestCatalogItem.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
              .toList();
          _isLoadingTests = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching lab tests for category $category: $e");
      if (mounted) {
        setState(() => _isLoadingTests = false);
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tests for $category: ${e.toString()}'))
        );
      }
    }
  }

  void _onTestSelected(LabTestCatalogItem? test) {
    if (!mounted || test == null) return;
    setState(() {
      _selectedLabTest = test;
      _amount = test.price;
      // If selected test requires lab visit and user had selected home collection, reset collection type
      if (test.requiresLabVisit && _collectionType == 'Home Collection') {
        _collectionType = 'Lab Visit';
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This test requires a lab visit. Collection type updated.')),
        );
      }
    });
  }
  
  void _updateSelectedTimeSlotString() {
    if (_selectedTime != null) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, _selectedTime!.hour, _selectedTime!.minute);
      _selectedTimeSlotString = DateFormat('hh:mm a').format(dt);
    } else {
      _selectedTimeSlotString = null;
    }
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)), // Cannot book for today or past
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != _selectedDate) {
      if (mounted) {
        setState(() {
          _selectedDate = picked;
        });
      }
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null && picked != _selectedTime) {
      if (mounted) {
        setState(() {
          _selectedTime = picked;
        });
        _updateSelectedTimeSlotString();
      }
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedLabTest == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a test.')));
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select date and time.')));
      return;
    }
    if (_collectionType == 'Home Collection' && (_currentUserAddress == null || _currentUserAddress!.isEmpty)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your address is not set for home collection. Please update in profile.')));
      return;
    }
     if (_selectedLabTest!.requiresLabVisit && _collectionType == 'Home Collection') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This test requires a lab visit. Please change collection type.')));
      return;
    }


    User? currentUser = _auth.currentUser;
    if (currentUser == null || _currentUserName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not fully loaded. Please wait.')));
      return;
    }

    setState(() => _isBooking = true);

    try {
      final DateTime fullBookingDateTime = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        _selectedTime!.hour, _selectedTime!.minute,
      );

      DocumentReference bookingRef = _firestore.collection('user_lab_test_bookings').doc();
      await bookingRef.set({
        'bookingId': bookingRef.id,
        'userId': currentUser.uid,
        'userName': _currentUserName,
        'labTestCatalogId': _selectedLabTest!.id,
        'testName': _selectedLabTest!.name,
        'testCategory': _selectedLabTest!.category,
        'priceAtBooking': _selectedLabTest!.price,
        'bookingDate': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'bookingTime': _selectedTimeSlotString,
        'dateTimeFull': Timestamp.fromDate(fullBookingDateTime),
        'collectionType': _collectionType,
        'addressForHomeCollection': _collectionType == 'Home Collection' ? _currentUserAddress : null,
        'selectedLabId': null, // For now, not selecting specific lab
        'selectedLabName': null,
        'status': 'booked',
        'paymentStatus': 'pending', // Assuming payment is handled later or is CoD
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lab test booked successfully!')),
        );
        Navigator.of(context).pop(); // Go back after booking
      }
    } catch (e) {
      debugPrint("Error booking lab test: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to book lab test: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = Theme.of(context).colorScheme.secondary;


    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Lab Test', style: TextStyle(color: Color(0xFF00695C), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1.0,
        iconTheme: const IconThemeData(color: Color(0xFF00695C)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location (Placeholder for now, could be user's address or lab search)
              const Text('Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF00695C))),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _collectionType == 'Home Collection' 
                                ? (_currentUserAddress ?? 'Set address in profile for home collection') 
                                : 'Lab Visit (Select Lab - Not Implemented)',
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Search or use current location',
                  prefixIcon: Icon(Icons.location_on_outlined, color: primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onTap: () {
                  // TODO: Implement location search or lab selection if 'Lab Visit'
                  ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text(_collectionType == 'Home Collection' && _currentUserAddress == null ? 'Please set your address in profile for home collection.' : 'Location selection not implemented yet.'))
                  );
                },
              ),
              const SizedBox(height: 20),

              // Select Test Category
              const Text('Select Test Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF00695C))),
              const SizedBox(height: 8),
              _isLoadingCategories
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      ),
                      hint: const Text('Select Category'),
                      value: _selectedTestCategory,
                      isExpanded: true,
                      items: _testCategories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedTestCategory = newValue;
                          });
                          _fetchLabTestsForCategory(newValue);
                        }
                      },
                      validator: (value) => value == null ? 'Please select a category' : null,
                    ),
              const SizedBox(height: 20),

              // Select Specific Test (if category is selected)
              if (_selectedTestCategory != null) ...[
                const Text('Select Test', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF00695C))),
                const SizedBox(height: 8),
                _isLoadingTests
                    ? const Center(child: CircularProgressIndicator())
                    : _labTestsForCategory.isEmpty
                        ? Text('No tests found for $_selectedTestCategory.', style: const TextStyle(color: Colors.grey))
                        : DropdownButtonFormField<LabTestCatalogItem>(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                            ),
                            hint: const Text('Select Test'),
                            value: _selectedLabTest,
                            isExpanded: true,
                            items: _labTestsForCategory.map((LabTestCatalogItem test) {
                              return DropdownMenuItem<LabTestCatalogItem>(
                                value: test,
                                child: Text("${test.name} (₹${test.price.toStringAsFixed(0)})"),
                              );
                            }).toList(),
                            onChanged: _onTestSelected,
                            validator: (value) => value == null ? 'Please select a test' : null,
                          ),
                const SizedBox(height: 20),
              ],
              
              // Date and Time Pickers
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300)
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDate != null ? DateFormat('MMM dd, yyyy').format(_selectedDate!) : 'Select Date',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Icon(Icons.calendar_today_outlined, color: primaryColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                           color: Colors.grey[100],
                           borderRadius: BorderRadius.circular(12),
                           border: Border.all(color: Colors.grey.shade300)
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedTime != null ? _selectedTime!.format(context) : 'Select Time',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Icon(Icons.access_time_outlined, color: primaryColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Collection Type
              const Text('Collection Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF00695C))),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Lab Visit'),
                      value: 'Lab Visit',
                      groupValue: _collectionType,
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() => _collectionType = value);
                        }
                      },
                      activeColor: primaryColor,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Home Collection'),
                      value: 'Home Collection',
                      groupValue: _collectionType,
                      onChanged: (_selectedLabTest != null && _selectedLabTest!.requiresLabVisit) 
                        ? null // Disable if test requires lab visit
                        : (String? value) {
                          if (value != null) {
                            if (_currentUserAddress == null || _currentUserAddress!.isEmpty) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please set your address in profile for home collection.')),
                              );
                            } else {
                              setState(() => _collectionType = value);
                            }
                          }
                        },
                      activeColor: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Amount Display
              if (_selectedLabTest != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.withOpacity(0.3))
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
                      Text('₹${_amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00695C))),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isBooking ? null : _confirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isBooking
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text('Confirm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
