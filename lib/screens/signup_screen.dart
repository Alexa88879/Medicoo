import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _auth = FirebaseAuth.instance; // Firebase Auth instance
  final _firestore = FirebaseFirestore.instance; // Firestore instance

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false; // To show loading indicator on button

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUpUser() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name.')),
      );
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address.')),
      );
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password.')),
      );
      return;
    }
    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create user with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? newUser = userCredential.user;

      if (newUser != null) {
        // Generate a simple patient ID (you might want a more robust system)
        String patientId = 'PAT${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

        // Store additional user information in Firestore
        await _firestore.collection('users').doc(newUser.uid).set({
          'uid': newUser.uid,
          'fullName': _nameController.text.trim(),
          'displayName': _nameController.text.trim(), // Initially same as full name
          'email': newUser.email,
          'role': 'patient', // Default role for app sign-ups
          'createdAt': Timestamp.now(),
          'patientId': patientId,
          // Initialize other fields as needed, possibly null or default values
          'age': null,
          'bloodGroup': null,
          'profilePictureUrl': null,
          'phoneNumber': null,
        });

        if (mounted) { // Check if the widget is still in the tree
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please try again.';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak (at least 6 characters).';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      debugPrint('Firebase Auth Exception: ${e.message}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
      debugPrint('Sign Up Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // U-shaped background (existing code)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: screenHeight * 0.45,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF4BA5A1),
                        Color(0xFF0C6661),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(35),
                      bottomRight: Radius.circular(35),
                    ),
                  ),
                ),
              ),
              // Center image with circular background (existing code)
              Positioned(
                top: screenHeight * 0.05,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: screenWidth * 0.330,
                    height: screenWidth * 0.40, // Should be same as width for circle
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(screenWidth * 0.02),
                    child: Image.asset(
                      'assets/sign_up_icon/center_image.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Scrollable sign up form
              Positioned(
                top: screenHeight * 0.30, // Adjusted to give more space for form
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.067,
                    vertical: screenHeight * 0.02,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(35),
                      topRight: Radius.circular(35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF008080),
                            fontFamily: 'Inter',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 25), // Increased spacing
                        // Full Name TextField (existing code)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                            child: Text('Full Name', style: TextStyle(color: Color(0xFF008080), fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
                          ),
                        ),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Enter your full name',
                            hintStyle: const TextStyle(color: Color(0xFF757575), fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.black26)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.black26)),
                          ),
                        ),
                        const SizedBox(height: 15),
                        // Email Address TextField (existing code)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                            child: Text('Email Address', style: TextStyle(color: Color(0xFF008080), fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
                          ),
                        ),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Enter your email address',
                            hintStyle: const TextStyle(color: Color(0xFF757575), fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.black26)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.black26)),
                          ),
                        ),
                        const SizedBox(height: 15),
                        // Create Password TextField (existing code)
                         const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                            child: Text('Create Password', style: TextStyle(color: Color(0xFF008080), fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
                          ),
                        ),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            hintStyle: const TextStyle(color: Color(0xFF757575), fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () {setState(() {_obscurePassword = !_obscurePassword;});},),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.black26)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.black26)),
                          ),
                        ),
                        const SizedBox(height: 15),
                        // Confirm Password TextField (existing code)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                            child: Text('Confirm Password', style: TextStyle(color: Color(0xFF008080), fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Inter')),
                          ),
                        ),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            hintText: 'Confirm your password',
                            hintStyle: const TextStyle(color: Color(0xFF757575), fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () {setState(() {_obscureConfirmPassword = !_obscureConfirmPassword;});},),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.black26)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.black26)),
                          ),
                        ),
                        const SizedBox(height: 30), // Increased spacing
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                          child: SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signUpUser, // Updated onPressed
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF008080),
                                elevation: 2,
                                shadowColor: const Color(0xFF008080).withAlpha(128),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Text(
                                      'Sign Up',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Inter', letterSpacing: 0.5),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account? ', style: TextStyle(fontSize: 16, color: Colors.black54, fontFamily: 'Inter')),
                            TextButton(
                              onPressed: _isLoading ? null : () {Navigator.pop(context);},
                              child: const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF008080), fontFamily: 'Inter')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}