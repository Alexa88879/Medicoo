// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart'; // Ensure HomeScreen is imported

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUpUser() async {
    if (!mounted) return;
    // Basic Input Validations (remain the same)
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
    if (_passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters long.')),
      );
      return;
    }
    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    UserCredential? userCredential; // For potential rollback

    try {
      // 1. Create Firebase Auth user
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? newUser = userCredential.user;

      if (newUser != null) {
        // Generate patientId as per your existing logic
        String generatedPatientId =
            'PATIENT${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        String nameInput = _nameController.text.trim();
        String emailInput = newUser.email!;

        // Write to the 'users' collection as per our schema
        DocumentReference userDocRef =
            _firestore.collection('users').doc(newUser.uid);

        Map<String, dynamic> userData = {
          'uid': newUser.uid, // Storing uid as a field as well
          'email': emailInput,
          'displayName': nameInput,
          'photoURL': null, // Not collected at email/password signup
          'providerId': 'password', // For email/password signup
          'createdAt': FieldValue.serverTimestamp(),
          // Initialize other fields from our schema with empty/null values
          'phoneNumber': null,
          'age': null,
          'bloodGroup': null, // Or ""
          'patientId': generatedPatientId,
          'fcmToken': null,
        };

        debugPrint(
            "Prepared to write to 'users' collection: $userData for UID: ${newUser.uid}");

        // Commit the user data to Firestore
        await userDocRef.set(userData);
        debugPrint(
            "User document created successfully in 'users' collection for: ${newUser.uid}");

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        // This case should ideally not be reached if createUserWithEmailAndPassword succeeds
        throw Exception("Firebase Auth user created but is null.");
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred during sign up.';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
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
      debugPrint(
          'FirebaseAuthException during sign up: ${e.code} - ${e.message}');
    } on FirebaseException catch (e) {
      // This catches Firestore specific errors during set/update
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save user data: ${e.message}')),
        );
      }
      debugPrint(
          'FirebaseException during Firestore write to users collection: ${e.code} - ${e.message}. UID was: ${userCredential?.user?.uid}');
      // Attempt to delete the orphaned Firebase Auth user if Firestore operation failed
      if (userCredential?.user != null) {
        debugPrint(
            "Attempting to delete orphaned auth user: ${userCredential!.user!.uid}");
        await userCredential.user!.delete().then((_) {
          debugPrint(
              "Orphaned auth user ${userCredential!.user!.uid} deleted successfully.");
        }).catchError((deleteError) {
          debugPrint(
              "Failed to delete orphaned auth user ${userCredential!.user!.uid}: $deleteError");
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Something went wrong during sign up. Please try again.')),
        );
      }
      debugPrint(
          'Generic sign up error: $e. UID was: ${userCredential?.user?.uid}');
      // Attempt to delete the orphaned Firebase Auth user in case of other errors post-auth
      if (userCredential?.user != null) {
        debugPrint(
            "Attempting to delete orphaned auth user (due to generic error): ${userCredential!.user!.uid}");
        await userCredential.user!.delete().then((_) {
          debugPrint(
              "Orphaned auth user ${userCredential!.user!.uid} deleted successfully (generic error case).");
        }).catchError((deleteError) {
          debugPrint(
              "Failed to delete orphaned auth user ${userCredential!.user!.uid} (generic error case): $deleteError");
        });
      }
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
    // --- UI CODE REMAINS UNCHANGED AS PER YOUR REQUEST ---
    // I will not repeat the UI build method here as it's unchanged.
    // The functional changes are within the _signUpUser method above.
    // Assume your existing build method is here.
    // For completeness, I'll paste your build method here without modification.
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder( 
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: screenHeight * 0.35, 
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, 
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4BA5A1), 
                        Color(0xFF0C6661), 
                      ],
                    ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(0), 
                        bottomRight: Radius.circular(0),
                      ),
                  ),
                ),
              ),
              Positioned(
                top: screenHeight * 0.06, 
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: screenWidth * 0.35, 
                    height: screenWidth * 0.35, 
                    padding: EdgeInsets.all(screenWidth * 0.015), 
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(230),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                    ),
                    child: ClipOval( 
                      child: Image.asset(
                        'assets/sign_up_icon/center_image.png', 
                        fit: BoxFit.cover, 
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: screenHeight * 0.28, 
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.07, 
                    vertical: screenHeight * 0.025,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40), 
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 15, 
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(), 
                    child: Column(
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        SizedBox(height: screenHeight * 0.02), 
                        const Text(
                          'Create Account', 
                          style: TextStyle(
                            fontSize: 30, 
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF008080),
                            fontFamily: 'Inter',
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.03),

                        _buildTextFieldLabel('Full Name'),
                        TextField(
                          controller: _nameController,
                          decoration: _inputDecoration(hintText: 'Enter your full name', icon: Icons.person_outline),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 18),

                        _buildTextFieldLabel('Email Address'),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration(hintText: 'Enter your email address', icon: Icons.email_outlined),
                        ),
                        const SizedBox(height: 18),

                        _buildTextFieldLabel('Create Password'),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: _inputDecoration(
                            hintText: 'Enter your password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                            obscureState: _obscurePassword,
                            onObscureToggle: () {
                              setState(() { _obscurePassword = !_obscurePassword; });
                            }
                          ),
                        ),
                        const SizedBox(height: 18),

                        _buildTextFieldLabel('Confirm Password'),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: _inputDecoration(
                            hintText: 'Confirm your password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                            obscureState: _obscureConfirmPassword,
                            onObscureToggle: () {
                              setState(() { _obscureConfirmPassword = !_obscureConfirmPassword; });
                            }
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.035), 

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52, 
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signUpUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF008080),
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shadowColor: const Color(0xFF008080).withAlpha(100),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12), 
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24, width: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : const Text(
                                      'Sign Up',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter', letterSpacing: 0.5),
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02), 

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account? ',
                                style: TextStyle(fontSize: 15, color: Colors.black54, fontFamily: 'Inter')),
                            TextButton(
                              onPressed: _isLoading ? null : () { Navigator.pop(context); },
                              child: const Text('Login',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF008080), fontFamily: 'Inter')),
                            ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.02), 
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

  Widget _buildTextFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0), 
        child: Text(label,
            style: const TextStyle(
                color: Color(0xFF00695C), 
                fontSize: 15, 
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter')),
      ),
    );
  }

  InputDecoration _inputDecoration({
      required String hintText,
      required IconData icon,
      bool isPassword = false,
      bool obscureState = false,
      VoidCallback? onObscureToggle
    }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
          color: Color(0xFF757575),
          fontSize: 14, 
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2),
      prefixIcon: Icon(icon, color: const Color(0xFF008080), size: 22), 
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(obscureState ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF008080), size: 22),
              onPressed: onObscureToggle,
            )
          : null,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: const BorderSide(color: Colors.grey)), 
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey)), 
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF008080), width: 2.0)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12), 
    );
  }
}
