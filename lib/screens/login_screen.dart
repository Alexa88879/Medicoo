// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_screen.dart';
import 'home_screen.dart'; // Used for navigation

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
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

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
      if (e.code == 'user-not-found' || e.code == 'INVALID_LOGIN_CREDENTIALS' || e.code == 'invalid-credential') {
        message = 'Invalid credentials. Please check your email and password.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      debugPrint('Firebase Auth Exception during login: ${e.code} - ${e.message}');
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
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    UserCredential? userCredential; // Initialize as nullable

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return; // User cancelled Google Sign-In
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user; // user is already nullable

      if (user != null) { // Null check for user
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final userDocSnapshot = await userDocRef.get();

        if (!userDocSnapshot.exists) {
          debugPrint("New Google user: ${user.uid}. Creating document in 'users' collection...");
          String generatedPatientId = 'PATG${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
          Map<String, dynamic> userData = {
            'uid': user.uid,
            'email': user.email,
            'displayName': user.displayName,
            'photoURL': user.photoURL,
            'providerId': 'google.com',
            'createdAt': FieldValue.serverTimestamp(),
            'role': 'patient',
            'phoneNumber': user.phoneNumber,
            'age': null,
            'bloodGroup': null,
            'patientId': generatedPatientId,
            'fcmTokens': [],
          };
          debugPrint("Attempting to create user document (Google Sign-In): $userData");
          await userDocRef.set(userData);
          debugPrint("User document created successfully for Google user: ${user.uid}");
        } else {
          debugPrint("Existing user profile for Google user: ${user.uid}. Checking for updates.");
          Map<String, dynamic> updates = {};
          Map<String, dynamic> existingData = userDocSnapshot.data()!;
          if(user.displayName != null && existingData['displayName'] != user.displayName) {
            updates['displayName'] = user.displayName;
          }
          if(user.photoURL != null && existingData['photoURL'] != user.photoURL) {
            updates['photoURL'] = user.photoURL;
          }
          if (existingData['role'] == null || existingData['role'] != 'patient') {
            updates['role'] = 'patient';
          }
          if (existingData['fcmTokens'] == null) {
            updates['fcmTokens'] = [];
          }
          if(updates.isNotEmpty) {
            updates['updatedAt'] = FieldValue.serverTimestamp();
            await userDocRef.update(updates);
            debugPrint("Updated user profile for ${user.uid} with: $updates");
          }
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()), // Remove user parameter since it's not defined
          );
        }
      } else {
        // This case should ideally not be reached if signInWithCredential was successful
        // but user object is null. Log it if it happens.
        debugPrint("Google Sign-In was successful but User object is null.");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Sign-In failed to retrieve user details.')));
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Google Sign-In Error. Please try again.';
      if (e.code == 'account-exists-with-different-credential') {
        message = 'An account already exists with the same email address but different sign-in credentials.';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Google Sign-In is not enabled for this project.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      debugPrint('FirebaseAuthException during Google Sign-In: ${e.code} - ${e.message}');
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save user data with Google: ${e.message ?? "Unknown Firebase error"}')));
      }
      debugPrint('FirebaseException (Google Sign-In): ${e.code} - ${e.message}. UID: ${userCredential?.user?.uid}');
      // ---- FIXED: Null check for userCredential and userCredential.user ----
      if (userCredential?.user != null) {
        await userCredential!.user!.delete().catchError((err) => debugPrint("Failed to delete orphaned Google auth user: $err"));
      }
      // ---- END FIX ----
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred with Google Sign-In: ${e.toString().split(']').last.trim()}')));
      }
      debugPrint('Generic Google Sign-In Error: $e. UID: ${userCredential?.user?.uid}');
      // ---- FIXED: Null check for userCredential and userCredential.user ----
      if (userCredential?.user != null) {
        await userCredential!.user!.delete().catchError((err) => debugPrint("Failed to delete orphaned Google auth user (generic): $err"));
      }
      // ---- END FIX ----
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address to reset password.')),
      );
      return;
    }
    if (mounted) {
      setState(() => _isLoading = true);
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error sending password reset email.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Stack(
                  children: [
                    Container(
                      height: screenHeight * 0.35,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFF159393),
                        image: DecorationImage(
                          image: AssetImage('assets/images/logo.png'),
                          fit: BoxFit.contain,
                          opacity: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: screenHeight * 0.28),
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
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
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Login',
                            style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: const Color(0xFF008080)),
                          ),
                          const SizedBox(height: 25),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('User ID (Email)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF008080))),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.poppins(),
                                decoration: InputDecoration(
                                  hintText: 'Enter your email address',
                                  hintStyle: GoogleFonts.poppins(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w300),
                                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF008080)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black26)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black26)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF008080), width: 2)),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text('Password', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF008080))),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: GoogleFonts.poppins(),
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  hintStyle: GoogleFonts.poppins(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w300),
                                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF008080)),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF008080)),
                                    onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); },
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black26)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black26)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF008080), width: 2)),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading ? null : _forgotPassword,
                                  child: Text('Forgot Password?', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF008080))),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _loginUser,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF008080),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    textStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                                      : const Text('Login'),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Expanded(child: Divider(color: Colors.black38)),
                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('OR', style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54))),
                                  const Expanded(child: Divider(color: Colors.black38)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SocialLoginButton(
                                text: 'Login With Google',
                                onPressed: _isLoading ? () {} : _signInWithGoogle,
                                icon: 'assets/icons/google.svg',
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Don't have an account? ", style: GoogleFonts.poppins(color: Colors.black54, fontSize: 15)),
                                  TextButton(
                                    onPressed: _isLoading ? null : () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen()));
                                    },
                                    child: Text('Sign Up', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF008080))),
                                  ),
                                ],
                              ),
                               const SizedBox(height: 30),
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
          side: const BorderSide(color: Colors.black38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(icon, height: 22),
            const SizedBox(width: 12),
            Text(text, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
