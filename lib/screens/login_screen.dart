import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:google_sign_in/google_sign_in.dart'; // Import GoogleSignIn
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore for Google Sign-In new user check
import 'signup_screen.dart';
import 'home_screen.dart'; // Ensure HomeScreen is imported

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false; // For loading indicators

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to login. Please check your credentials.';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else if (e.code == 'invalid-credential') {
        message = 'Invalid credentials. Please check your email and password.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      debugPrint('Firebase Auth Exception during login: ${e.toString()}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
      debugPrint('Login Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null && mounted) {
        // The user canceled the sign-in
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser!.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // Check if this is a new Google user or existing
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          // New user, store their info in Firestore
          String patientId = 'PATG${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
          await userDocRef.set({
            'uid': user.uid,
            'fullName': user.displayName ?? 'Google User',
            'displayName': user.displayName ?? 'Google User',
            'email': user.email,
            'role': 'patient', // Default role
            'createdAt': Timestamp.now(),
            'profilePictureUrl': user.photoURL,
            'patientId': patientId,
            'age': null,
            'bloodGroup': null,
            'phoneNumber': user.phoneNumber, // May or may not be available
          });
        }
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in with Google: ${e.toString().split(']').last}')), // More concise error
        );
      }
      debugPrint('Google Sign-In Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address to reset password.')),
      );
      return;
    }
    setState(() {
      _isLoading = true; // Can use the same loading state or a specific one
    });
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent. Please check your inbox.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Failed to send reset email.";
      if (e.code == 'user-not-found') {
        message = "No user found for that email.";
      } else if (e.code == 'invalid-email') {
        message = "The email address is not valid.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error sending password reset email.')));
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            // physics: const NeverScrollableScrollPhysics(), // Allow scrolling if content overflows
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight( // Ensures column children take up full height if possible
                child: Stack(
                  children: [
                    Container( // Background Image/Color (existing code)
                      height: screenHeight * 0.35,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFF159393),
                        image: DecorationImage(
                          image: AssetImage('assets/images/logo.png'),
                          fit: BoxFit.cover,
                          opacity: 0.8,
                        ),
                      ),
                    ),
                    Container( // Login Form Area
                      margin: EdgeInsets.only(top: screenHeight * 0.30), // Adjusted margin
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20), // Adjusted padding
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(35),
                          topRight: Radius.circular(35),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                        children: [
                          const Text(
                            'Login',
                            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF008080), fontFamily: 'Inter'),
                          ),
                          const SizedBox(height: 20), // Increased spacing
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('User ID (Email)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF008080), fontFamily: 'Inter')),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: 'Enter your email address',
                                  hintStyle: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w200),
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.black26)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.black26)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Color(0xFF008080))),
                                ),
                              ),
                              const SizedBox(height: 15),
                              const Text('Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF008080), fontFamily: 'Inter')),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  hintStyle: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w200),
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); },
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.black26)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.black26)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Color(0xFF008080))),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading ? null : _forgotPassword, // Call forgot password
                                  child: const Text('Forgot Password?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF008080), fontFamily: 'Inter')),
                                ),
                              ),
                              const SizedBox(height: 15),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _loginUser, // Call login user
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF008080),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: _isLoading && ModalRoute.of(context)?.isCurrent == true // Check if this button triggered loading
                                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                                      : const Text('Login', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Inter')),
                                ),
                              ),
                              const SizedBox(height: 15),
                              const Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.black38)),
                                  Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('OR', style: TextStyle(fontSize: 14, color: Colors.black, fontFamily: 'Inter'))),
                                  Expanded(child: Divider(color: Colors.black38)),
                                ],
                              ),
                              const SizedBox(height: 15),
                              SocialLoginButton(
                                text: 'Login With Google',
                                onPressed: _isLoading ? () {} : _signInWithGoogle, // Call Google sign-in
                                icon: 'assets/icons/google.svg', // Make sure this asset exists
                              ),
                              const SizedBox(height: 15),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Don't have an account? ", style: TextStyle(fontFamily: 'Inter', color: Colors.black54, fontSize: 16)),
                                  TextButton(
                                    onPressed: _isLoading ? null : () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen()));
                                    },
                                    child: const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF008080), fontFamily: 'Inter')),
                                  ),
                                ],
                              ),
                               const SizedBox(height: 20), // Ensure some space at the bottom for scrolling
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SocialLoginButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final String icon;
  const SocialLoginButton({
    required this.text,
    required this.onPressed,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Colors.black26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(icon, height: 24), // Ensure this asset exists
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54, fontFamily: 'Inter')), // Slightly bolder text
          ],
        ),
      ),
    );
  }
}