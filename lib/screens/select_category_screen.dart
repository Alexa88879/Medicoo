// screens/select_category_screen.dart
import 'package:flutter/material.dart';
import 'select_doctor_screen.dart'; // We will create this next

class Category {
  final String name;
  final IconData iconData; // Or String for image asset path

  Category({required this.name, required this.iconData});
}

class SelectCategoryScreen extends StatefulWidget {
  const SelectCategoryScreen({super.key});

  @override
  State<SelectCategoryScreen> createState() => _SelectCategoryScreenState();
}

class _SelectCategoryScreenState extends State<SelectCategoryScreen> {
  // Define your categories here. You can expand this list.
  // For icons, I'm using Material Icons. You can use custom SVGs/images.
  final List<Category> _categories = [
    Category(name: 'Dental care', iconData: Icons.medical_services_outlined), // Placeholder, find better icons
    Category(name: 'Heart', iconData: Icons.favorite_border),
    Category(name: 'Kidney Issues', iconData: Icons.water_drop_outlined), // Placeholder
    Category(name: 'Cancer', iconData: Icons.healing_outlined), // Placeholder
    Category(name: 'Ayurveda', iconData: Icons.spa_outlined),
    Category(name: 'Mental Wellness', iconData: Icons.psychology_outlined),
    Category(name: 'Homoeopath', iconData: Icons.eco_outlined), // Placeholder
    Category(name: 'Physiotherapy', iconData: Icons.sports_kabaddi_outlined),
    Category(name: 'General Surgery', iconData: Icons.content_cut_outlined),
    Category(name: 'Urinary Issues', iconData: Icons.water_damage_outlined), // Placeholder
    Category(name: 'Lungs and Breathing', iconData: Icons.air_outlined),
    Category(name: 'General physician', iconData: Icons.person_outline),
    Category(name: 'Eye Specialist', iconData: Icons.visibility_outlined),
    Category(name: 'Women\'s Health', iconData: Icons.pregnant_woman_outlined),
    Category(name: 'Diet & Nutrition', iconData: Icons.restaurant_outlined),
    Category(name: 'Skin & Hair', iconData: Icons.face_retouching_natural_outlined),
    Category(name: 'Bones & Joints', iconData: Icons.accessibility_new_outlined), // Placeholder
    Category(name: 'Child Specialist', iconData: Icons.child_care_outlined),
    // Add more categories as per your images
  ];

  List<Category> _filteredCategories = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredCategories = _categories;
    _searchController.addListener(_filterCategories);
  }

  void _filterCategories() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredCategories = _categories;
      });
    } else {
      setState(() {
        _filteredCategories = _categories
            .where((category) => category.name.toLowerCase().contains(query))
            .toList();
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCategories);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Find a Doctor for your Health Problem',
          style: TextStyle(color: Color(0xFF00695C), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white, // Or your theme's app bar color
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
            child: ListView.builder(
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
                        builder: (context) => SelectDoctorScreen(specialization: category.name),
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