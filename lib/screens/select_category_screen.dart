// lib/screens/select_category_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'select_doctor_screen.dart';

// Updated Category model
class Category {
  final String id; // Firestore document ID
  final String name;
  final IconData iconData;
  final String? imageUrl; // Optional: from Firestore schema

  Category({
    required this.id,
    required this.name,
    required this.iconData,
    this.imageUrl,
  });
}

class SelectCategoryScreen extends StatefulWidget {
  final String? bookingType; // "in_person" or "video"

  const SelectCategoryScreen({super.key, this.bookingType = "in_person"}); // Default to in_person

  @override
  State<SelectCategoryScreen> createState() => _SelectCategoryScreenState();
}

class _SelectCategoryScreenState extends State<SelectCategoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Local list primarily for icon mapping fallback
  final List<Category> _localIconCategories = [
    Category(id: '', name: 'Dental care', iconData: Icons.medical_services_outlined),
    Category(id: '', name: 'Heart', iconData: Icons.favorite_border),
    Category(id: '', name: 'Kidney Issues', iconData: Icons.water_drop_outlined),
    Category(id: '', name: 'Cancer', iconData: Icons.healing_outlined),
    Category(id: '', name: 'Ayurveda', iconData: Icons.spa_outlined),
    Category(id: '', name: 'Mental Wellness', iconData: Icons.psychology_outlined),
    Category(id: '', name: 'Homoeopath', iconData: Icons.eco_outlined),
    Category(id: '', name: 'Physiotherapy', iconData: Icons.sports_kabaddi_outlined),
    Category(id: '', name: 'General Surgery', iconData: Icons.content_cut_outlined),
    Category(id: '', name: 'Urinary Issues', iconData: Icons.water_damage_outlined),
    Category(id: '', name: 'Lungs and Breathing', iconData: Icons.air_outlined),
    Category(id: '', name: 'General physician', iconData: Icons.person_outline),
    Category(id: '', name: 'Eye Specialist', iconData: Icons.visibility_outlined),
    Category(id: '', name: 'Women\'s Health', iconData: Icons.pregnant_woman_outlined),
    Category(id: '', name: 'Diet & Nutrition', iconData: Icons.restaurant_outlined),
    Category(id: '', name: 'Skin & Hair', iconData: Icons.face_retouching_natural_outlined),
    Category(id: '', name: 'Bones & Joints', iconData: Icons.accessibility_new_outlined),
    Category(id: '', name: 'Child Specialist', iconData: Icons.child_care_outlined),
  ];

  List<Category> _allFetchedCategories = [];
  List<Category> _filteredCategories = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCategoriesFromFirestore();
    _searchController.addListener(_filterCategories);
  }

  IconData _getIconForCategory(String categoryName) {
    final foundCategory = _localIconCategories.firstWhere(
      (cat) => cat.name.toLowerCase() == categoryName.toLowerCase(),
      orElse: () => Category(id: '', name: 'Default', iconData: Icons.category_outlined),
    );
    return foundCategory.iconData;
  }

  Future<void> _fetchCategoriesFromFirestore() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      QuerySnapshot querySnapshot =
          await _firestore.collection('categories').orderBy('name').get();

      List<Category> fetchedCategories = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String name = data['name'] ?? 'Unnamed Category';
        return Category(
          id: doc.id,
          name: name,
          iconData: _getIconForCategory(name),
          imageUrl: data['imageUrl'],
        );
      }).toList();

      if (mounted) {
        setState(() {
          _allFetchedCategories = fetchedCategories;
          _filteredCategories = _allFetchedCategories;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to load categories. Please try again.";
        });
      }
    }
  }

  void _filterCategories() {
    final query = _searchController.text.toLowerCase();
    if (!mounted) return;

    setState(() {
      if (query.isEmpty) {
        _filteredCategories = _allFetchedCategories;
      } else {
        _filteredCategories = _allFetchedCategories
            .where((category) => category.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCategories);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = widget.bookingType == "video"
        ? 'Video Consultation: Select Speciality'
        : 'Find a Doctor for your Health Problem';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(color: Color(0xFF00695C), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1.0,
        iconTheme: const IconThemeData(color: Color(0xFF00695C)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Symptoms / Specialities',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 16)),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: _fetchCategoriesFromFirestore,
                                child: const Text('Retry'),
                              )
                            ],
                          ),
                        ),
                      )
                    : _filteredCategories.isEmpty && _searchController.text.isNotEmpty
                        ? const Center(child: Text("No categories found for your search.", style: TextStyle(fontSize: 16, color: Colors.grey)))
                        : _filteredCategories.isEmpty && _searchController.text.isEmpty
                            ? const Center(child: Text("No categories available.", style: TextStyle(fontSize: 16, color: Colors.grey)))
                            : ListView.builder(
                                itemCount: _filteredCategories.length,
                                itemBuilder: (context, index) {
                                  final category = _filteredCategories[index];
                                  return ListTile(
                                    leading: Icon(category.iconData, color: Theme.of(context).primaryColor),
                                    title: Text(category.name),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SelectDoctorScreen(
                                            specialization: category.name,
                                            bookingType: widget.bookingType, // Pass bookingType
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
          ),
        ],
      ),
    );
  }
}
