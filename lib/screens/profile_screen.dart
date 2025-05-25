// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart'; // For logout
import 'package:google_fonts/google_fonts.dart'; // For consistent theming

import 'login_screen.dart'; // For navigation after logout
import 'account_details_screen.dart';
import 'allergy_list_screen.dart';
import 'family_screen.dart';
// import '../notification_center_screen.dart'; // Import if not navigating by route name

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      try {
        DocumentSnapshot userDocSnap =
            await _firestore.collection('users').doc(_currentUser!.uid).get();
        if (mounted) {
          setState(() {
            if (userDocSnap.exists) {
              _userData = userDocSnap.data() as Map<String, dynamic>?;
            } else {
              _userData = {
                'displayName': _currentUser?.displayName,
                'email': _currentUser?.email,
                'photoURL': _currentUser?.photoURL,
              };
            }
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error fetching user data for profile: $e");
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading profile data: ${e.toString()}', style: GoogleFonts.poppins())),
          );
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
         Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
      }
    }
  }

  Future<void> _logoutUser() async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirm Logout', style: GoogleFonts.poppins()),
          content: Text('Are you sure you want to log out?', style: GoogleFonts.poppins()),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: GoogleFonts.poppins()),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: Text('Logout', style: GoogleFonts.poppins(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      try {
        bool isGoogleUser = _auth.currentUser?.providerData
                .any((userInfo) => userInfo.providerId == GoogleAuthProvider.PROVIDER_ID) ?? false;

        if (isGoogleUser) {
          await _googleSignIn.signOut();
          debugPrint("Google user signed out.");
        }
        
        await _auth.signOut();
        debugPrint("Firebase user signed out.");

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging out: ${e.toString()}', style: GoogleFonts.poppins())),
          );
        }
        debugPrint("Logout error: $e");
      }
    }
  }

  Widget _buildProfileOptionItem({
    required String assetName,
    required String title,
    VoidCallback? onTap,
  }) {
    String fullAssetPath = 'assets/icons/profile/$assetName';

    return ListTile(
      leading: SvgPicture.asset(
        fullAssetPath,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(Theme.of(context).primaryColor, BlendMode.srcIn),
        placeholderBuilder: (BuildContext context) => Icon(Icons.error_outline, color: Colors.red.shade300),
      ),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade800)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade500),
      onTap: onTap ?? () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title tapped (Not Implemented)', style: GoogleFonts.poppins())),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String displayName = _isLoading ? "Loading..." : (_userData?['displayName'] ?? _currentUser?.displayName ?? "Name");
    String displayEmail = _isLoading ? " " : (_userData?['email'] ?? _currentUser?.email ?? "email@example.com");
    String? photoURL = _userData?['photoURL'] ?? _currentUser?.photoURL;
    
    final Color iconThemeColor = Theme.of(context).primaryColor;
    final appBarTheme = Theme.of(context).appBarTheme;


    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: appBarTheme.titleTextStyle ?? GoogleFonts.poppins(color: const Color(0xFF00695C), fontWeight: FontWeight.bold)),
        backgroundColor: appBarTheme.backgroundColor ?? Colors.white,
        elevation: appBarTheme.elevation ?? 1.0,
        iconTheme: appBarTheme.iconTheme ?? IconThemeData(color: iconThemeColor),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none_outlined, color: iconThemeColor, size: 28),
            // ---- MODIFIED THIS onPressed CALLBACK ----
            onPressed: () {
              Navigator.of(context).pushNamed('/notification_center');
            },
            // ---- END MODIFICATION ----
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(iconThemeColor)))
          : RefreshIndicator(
            onRefresh: _loadUserData,
            color: iconThemeColor,
            child: ListView(
                padding: const EdgeInsets.all(0),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: (photoURL != null && photoURL.isNotEmpty)
                              ? NetworkImage(photoURL)
                              : null,
                          child: (photoURL == null || photoURL.isEmpty)
                              ? Icon(Icons.person, size: 35, color: Colors.grey.shade600)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayEmail,
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

                  _buildProfileOptionItem(
                    assetName: 'account_icon.svg',
                    title: 'Account',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AccountDetailsScreen()),
                      ).then((dataWasUpdated) {
                        if (dataWasUpdated == true && mounted) {
                          _loadUserData();
                        }
                      });
                    }
                  ),
                  _buildProfileOptionItem(
                    assetName: 'allergic_icon.svg',
                    title: 'Allergic',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AllergyListScreen()),
                      );
                    },
                  ),
                   _buildProfileOptionItem(
                    assetName: 'family_icon.svg',
                    title: 'Family',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FamilyScreen()),
                      );
                    },
                  ),
                  _buildProfileOptionItem(assetName: 'reports_icon.svg', title: 'My Reports'),
                  _buildProfileOptionItem(assetName: 'orders_icon.svg', title: 'My Orders'),
                  _buildProfileOptionItem(assetName: 'insurance_icon.svg', title: 'Insurances'),
                  _buildProfileOptionItem(assetName: 'history_icon.svg', title: 'History'),

                  const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: Color(0xFFEEEEEE)),

                  _buildProfileOptionItem(assetName: 'settings_icon.svg', title: 'Setting'),
                  _buildProfileOptionItem(assetName: 'help_icon.svg', title: 'Help and Support'),
                  
                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: OutlinedButton.icon(
                      icon: SvgPicture.asset(
                        'assets/icons/profile/logout_icon.svg',
                         width: 20, height: 20,
                         colorFilter: ColorFilter.mode(Colors.red.shade700, BlendMode.srcIn),
                         placeholderBuilder: (BuildContext context) => Icon(Icons.exit_to_app, color: Colors.red.shade300),
                      ),
                      label: Text(
                        'Log out',
                        style: GoogleFonts.poppins(fontSize: 16, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                      ),
                      onPressed: _logoutUser,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: BorderSide(color: Colors.red.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
          ),
    );
  }
}
