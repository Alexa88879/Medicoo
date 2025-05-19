// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_screen.dart';
import 'home_screen.dart'; // Used for navigation

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance; // Instance of Firestore

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

      // Navigation to HomeScreen is handled by StreamBuilder in main.dart
      // So, no explicit navigation here after successful login is strictly needed
      // if main.dart's StreamBuilder is correctly set up.
      // However, if you want immediate navigation before StreamBuilder rebuilds:
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
        // This code can be triggered for various reasons including user-not-found or wrong-password
        // depending on the Firebase SDK version and backend behavior.
        message = 'Invalid credentials. Please check your email and password.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      debugPrint(
          'Firebase Auth Exception during login: ${e.code} - ${e.message}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong. Please try again.')),
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
    UserCredential? userCredential; // To hold the credential for potential rollback

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User cancelled the Google Sign In
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // Use 'users' collection as per our schema
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final userDocSnapshot = await userDocRef.get();

        if (!userDocSnapshot.exists) {
          // New user: Create document in 'users' collection
          debugPrint(
              "New Google user: ${user.uid}. Creating document in 'users' collection...");
          
          // Generate patientId as per your existing logic
          String generatedPatientId = 'PATG${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

          Map<String, dynamic> userData = {
            'uid': user.uid, // Storing uid as a field as well
            'email': user.email,
            'displayName': user.displayName, // Mapped from Google's displayName
            'photoURL': user.photoURL,       // Mapped from Google's photoURL
            'providerId': 'google.com',
            'createdAt': FieldValue.serverTimestamp(),
            'phoneNumber': user.phoneNumber, // From Google, might be null
            // Initialize other fields from our schema with empty/null values
            'age': null,
            'bloodGroup': null, // Or ""
            'patientId': generatedPatientId, 
            'fcmToken': null,
          };

          await userDocRef.set(userData);
          debugPrint(
              "User document created successfully in 'users' collection for Google user: ${user.uid}");
        } else {
          // Existing user: Optionally update certain fields
          debugPrint(
              "Existing user profile for Google user: ${user.uid}. Checking for updates in 'users' collection.");
          Map<String, dynamic> existingUserData =
              userDocSnapshot.data() as Map<String, dynamic>;
          Map<String, dynamic> updates = {};

          // Update email if changed (and not null from Google)
          if (user.email != null && existingUserData['email'] != user.email) {
            updates['email'] = user.email;
          }
          // Update displayName if changed (and not null/empty from Google)
          if (user.displayName != null &&
              user.displayName!.isNotEmpty &&
              existingUserData['displayName'] != user.displayName) {
            updates['displayName'] = user.displayName;
          }
          // Update photoURL if changed (and not null from Google)
          if (user.photoURL != null && existingUserData['photoURL'] != user.photoURL) {
            updates['photoURL'] = user.photoURL;
          }
           // Update phoneNumber if changed (can be set to null if removed from Google)
          if (existingUserData['phoneNumber'] != user.phoneNumber) {
            updates['phoneNumber'] = user.phoneNumber;
          }


          if (updates.isNotEmpty) {
            await userDocRef.update(updates);
            debugPrint(
                "Updated user profile for ${user.uid} in 'users' collection with: $updates");
          }
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In Error: ${e.message}')),
        );
      }
      debugPrint(
          'FirebaseAuthException during Google Sign-In: ${e.code} - ${e.message}');
    } on FirebaseException catch (e) {
      // This catches Firestore specific errors during set/update
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to save user data with Google: ${e.message}')),
        );
      }
      debugPrint(
          'FirebaseException during Firestore write (Google Sign-In): ${e.code} - ${e.message}. UID was: ${userCredential?.user?.uid}');
      // Attempt to delete the orphaned Firebase Auth user if Firestore operation failed
      if (userCredential?.user != null) {
        debugPrint(
            "Attempting to delete orphaned Google auth user: ${userCredential!.user!.uid}");
        await userCredential.user!.delete().then((_) {
          debugPrint(
              "Orphaned Google auth user ${userCredential!.user!.uid} deleted successfully.");
        }).catchError((deleteError) {
          debugPrint(
              "Failed to delete orphaned Google auth user ${userCredential!.user!.uid}: $deleteError");
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'An unexpected error occurred with Google Sign-In: ${e.toString().split(']').last.trim()}')),
        );
      }
      debugPrint(
          'Generic Google Sign-In Error: $e. UID was: ${userCredential?.user?.uid}');
      // Attempt to delete the orphaned Firebase Auth user in case of other errors post-auth
      if (userCredential?.user != null) {
        debugPrint(
            "Attempting to delete orphaned Google auth user (due to generic error): ${userCredential!.user!.uid}");
        await userCredential.user!.delete().then((_) {
          debugPrint(
              "Orphaned Google auth user ${userCredential!.user!.uid} deleted successfully (generic error case).");
        }).catchError((deleteError) {
          debugPrint(
              "Failed to delete orphaned Google auth user ${userCredential!.user!.uid} (generic error case): $deleteError");
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

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please enter your email address to reset password.')),
      );
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Password reset email sent. Please check your inbox.')),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error sending password reset email.')));
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
    // --- UI CODE REMAINS UNCHANGED AS PER YOUR REQUEST ---
    // I will not repeat the UI build method here as it's unchanged.
    // The functional changes are within the _loginUser, _signInWithGoogle, 
    // and _forgotPassword methods above.
    // Assume your existing build method is here.
    // For completeness, I'll paste your build method here without modification.
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
                          ]
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          const Text(
                            'Login',
                            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF008080), fontFamily: 'Inter'),
                          ),
                          const SizedBox(height: 25), 
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
                                  hintStyle: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w300), 
                                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF008080)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black26)), 
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black26)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF008080), width: 2)),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12), 
                                ),
                              ),
                              const SizedBox(height: 18), 
                              const Text('Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF008080), fontFamily: 'Inter')),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  hintStyle: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w300),
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
                                  child: const Text('Forgot Password?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF008080), fontFamily: 'Inter')), 
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
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                                      : const Text('Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter')), 
                                ),
                              ),
                              const SizedBox(height: 20), 
                              const Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.black38)),
                                  Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('OR', style: TextStyle(fontSize: 14, color: Colors.black54, fontFamily: 'Inter'))), 
                                  Expanded(child: Divider(color: Colors.black38)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SocialLoginButton(
                                text: 'Login With Google',
                                onPressed: _isLoading ? () {} : _signInWithGoogle, // Ensure _isLoading disables this too
                                icon: 'assets/icons/google.svg', 
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Don't have an account? ", style: TextStyle(fontFamily: 'Inter', color: Colors.black54, fontSize: 15)), 
                                  TextButton(
                                    onPressed: _isLoading ? null : () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen()));
                                    },
                                    child: const Text('Sign Up', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF008080), fontFamily: 'Inter')), 
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

// SocialLoginButton widget remains unchanged as it's a UI component.
// I'll paste your SocialLoginButton code here without modification.
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
            Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87, fontFamily: 'Inter')), 
          ],
        ),
      ),
    );
  }
}
