import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hii Name',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006D6D),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF006D6D)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Name',
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFF006D6D),
                            ),
                          ),
                          Text(
                            'Id: 12345',
                            style: TextStyle(color: Color(0xFF006D6D)),
                          ),
                          Text(
                            'Age: 54',
                            style: TextStyle(color: Color(0xFF006D6D)),
                          ),
                          Text(
                            'Blood Group',
                            style: TextStyle(color: Color(0xFF006D6D)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF006D6D)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildOptionCard(
                    icon: Icons.medical_services_outlined,
                    title: 'Book',
                    subtitle: 'Appointment',
                    onTap: () {
                      // Handle Book Appointment tap
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Book Appointment tapped')),
                      );
                    },
                  ),
                  _buildOptionCard(
                    icon: Icons.science_outlined,
                    title: 'Book',
                    subtitle: 'Lab test',
                    onTap: () {
                      // Handle Book Lab test tap
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Book Lab test tapped')),
                      );
                    },
                  ),
                  _buildOptionCard(
                    icon: Icons.medical_information_outlined,
                    title: 'Order',
                    subtitle: 'Appointment',
                    onTap: () {
                      // Handle Order Appointment tap
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order Appointment tapped')),
                      );
                    },
                  ),
                  _buildOptionCard(
                    icon: Icons.video_call_outlined,
                    title: 'Consultation',
                    subtitle: '',
                    onTap: () {
                      // Handle Consultation tap
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Consultation tapped')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () {
                  // Handle Prescription tap
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Prescription tapped')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Prescription',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Spacer(),
                      Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Appointments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006D6D),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  // Handle Appointment tap
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Appointment details tapped')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: Color(0xFF006D6D)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Name',
                            style: TextStyle(
                              color: Color(0xFF006D6D),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Date-Time',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF006D6D)),
                        ),
                        child: const Icon(
                          Icons.star,
                          color: Color(0xFF006D6D),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavIcon(Icons.home, true),
                  _buildNavIcon(Icons.folder_outlined, false),
                  _buildNavIcon(Icons.qr_code_scanner_outlined, false),
                  _buildNavIcon(Icons.location_on_outlined, false),
                  _buildNavIcon(Icons.person_outline, false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF006D6D)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF006D6D),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, bool isActive) {
    return IconButton(
      icon: Icon(
        icon,
        color: isActive ? const Color(0xFF006D6D) : Colors.grey,
      ),
      onPressed: () {
        // Handle navigation icon tap
      },
    );
  }
}