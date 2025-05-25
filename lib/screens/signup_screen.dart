// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart'; // Assuming you use this for consistency
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

    // Basic Input Validations
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
        const SnackBar(content: Text('Password must be at least 6 characters long.')),
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

    UserCredential? userCredential;

    try {
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? newUser = userCredential.user;

      if (newUser != null) {
        String generatedPatientId = 'PATIENT${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        String nameInput = _nameController.text.trim();
        String emailInput = newUser.email!; // newUser.email should not be null here

        DocumentReference userDocRef = _firestore.collection('users').doc(newUser.uid);

        Map<String, dynamic> userData = {
          'uid': newUser.uid,
          'email': emailInput,
          'displayName': nameInput,
          'photoURL': newUser.photoURL, // Can be null
          'providerId': 'password', // For email/password signup
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'patient', // Default role for new signups
          'age': null, // Initialize as null, user can update later
          'bloodGroup': null, // Initialize as null
          'patientId': generatedPatientId,
          'fcmTokens': [], // Initialize as empty list for notifications
          'phoneNumber': null, // Initialize as null
          // Ensure all fields required by your Firestore security rules for user creation are present
        };

        debugPrint("Attempting to create user document in Firestore: $userData for UID: ${newUser.uid}");
        await userDocRef.set(userData);
        debugPrint("User document created successfully in 'users' collection for: ${newUser.uid}");

        if (mounted) {
          // ---- THIS IS THE FIX: Pass the newly created user object to HomeScreen ----
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
          // ---- END FIX ----
        }
      } else {
        // This case should be rare if createUserWithEmailAndPassword succeeds
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
      debugPrint('FirebaseAuthException during sign up: ${e.code} - ${e.message}');
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save user data: ${e.message}')),
        );
      }
      debugPrint('FirebaseException during Firestore write to users collection: ${e.code} - ${e.message}. UID was: ${userCredential?.user?.uid}');
      // Attempt to delete the orphaned auth user if Firestore write fails
      if (userCredential?.user != null) {
        debugPrint("Attempting to delete orphaned auth user: ${userCredential!.user!.uid}");
        await userCredential.user!.delete().then((_) {
          debugPrint("Orphaned auth user ${userCredential!.user!.uid} deleted successfully.");
        }).catchError((deleteError) {
          debugPrint("Failed to delete orphaned auth user ${userCredential!.user!.uid}: $deleteError");
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong during sign up. Please try again.')),
        );
      }
      debugPrint('Generic sign up error: $e. UID was: ${userCredential?.user?.uid}');
      // Attempt to delete the orphaned auth user
      if (userCredential?.user != null) {
        debugPrint("Attempting to delete orphaned auth user (due to generic error): ${userCredential!.user!.uid}");
        await userCredential.user!.delete().then((_) {
          debugPrint("Orphaned auth user ${userCredential!.user!.uid} deleted successfully (generic error case).");
        }).catchError((deleteError) {
          debugPrint("Failed to delete orphaned auth user ${userCredential!.user!.uid} (generic error case): $deleteError");
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
    // Using GoogleFonts for consistency
    final poppinsRegular = GoogleFonts.poppins();
    final poppinsMedium = GoogleFonts.poppins(fontWeight: FontWeight.w500);
    final poppinsBold = GoogleFonts.poppins(fontWeight: FontWeight.bold);
    final poppinsW700 = GoogleFonts.poppins(fontWeight: FontWeight.w700);


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
                    // Removed bottom circular border to match login screen
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
                        ]),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/sign_up_icon/center_image.png', // Ensure this asset exists
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
                        Text(
                          'Create Account',
                          style: GoogleFonts.poppins( // Using Poppins
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF008080),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.03),

                        _buildTextFieldLabel('Full Name'),
                        TextField(
                          controller: _nameController,
                          style: poppinsRegular,
                          decoration: _inputDecoration(hintText: 'Enter your full name', icon: Icons.person_outline),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 18),

                        _buildTextFieldLabel('Email Address'),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: poppinsRegular,
                          decoration: _inputDecoration(hintText: 'Enter your email address', icon: Icons.email_outlined),
                        ),
                        const SizedBox(height: 18),

                        _buildTextFieldLabel('Create Password'),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: poppinsRegular,
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
                          style: poppinsRegular,
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
                                textStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5), // Using Poppins
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24, width: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : const Text('Sign Up'),
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account? ', style: GoogleFonts.poppins(fontSize: 15, color: Colors.black54)),
                            TextButton(
                              onPressed: _isLoading ? null : () { Navigator.pop(context); },
                              child: Text('Login', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF008080))),
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
            style: GoogleFonts.poppins( // Using Poppins
                color: const Color(0xFF00695C),
                fontSize: 15,
                fontWeight: FontWeight.w500)),
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
      hintStyle: GoogleFonts.poppins( // Using Poppins
          color: const Color(0xFF757575),
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
