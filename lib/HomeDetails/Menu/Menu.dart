import 'package:express_car/Handle_car/HandleBussiness.dart';
import 'package:express_car/HomeDetails/Menu/Menus_Files/Account.dart';
import 'package:express_car/HomeDetails/Menu/Menus_Files/ChangePassword.dart';
import 'package:express_car/HomeDetails/Menu/Menus_Files/EditProfile.dart';
import 'package:express_car/HomeDetails/Menu/Menus_Files/ViewProfile.dart';
import 'package:express_car/Splash/get_start.dart';
import 'package:express_car/Admin/admin_panel.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:express_car/services/user_presence_service.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({Key? key}) : super(key: key);

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String _displayName = 'Guest User';
  String _photoURL = '';
  String _role = 'user';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': user.displayName ?? 'Guest User',
        'photoURL': user.photoURL ?? '',
        'email': user.email ?? '',
        'role': 'user',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      setState(() {
        _displayName = data?['displayName'] ?? user.displayName ?? 'Guest User';
        _photoURL = data?['photoURL'] ?? user.photoURL ?? '';
        _role = data?['role'] ?? 'user';
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {
        _displayName = user.displayName ?? 'Guest User';
        _photoURL = user.photoURL ?? '';
        _role = 'user';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                "Menu",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),

              /// Profile Row (data loaded in state)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ViewProfilePage()),
                  );
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: (_photoURL.isNotEmpty)
                          ? NetworkImage(_photoURL)
                          : const AssetImage("assets/images/profile.jpg")
                                as ImageProvider,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        _displayName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.grey, thickness: 1),
              const SizedBox(height: 20),

              /// Menu Items
              Expanded(
                child: ListView(
                  children: [
                    _buildMenuItem(
                      Icons.person_outline,
                      "Account",
                      context,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AccountPage()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      Icons.badge_outlined,
                      "View Profile",
                      context,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ViewProfilePage()),
                        );
                      },
                    ),
                    _buildMenuItem(Icons.edit, "Edit Profile", context, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EditProfilePage()),
                      );
                    }),
                    // show admin panel link for administrators
                    if (_role == 'admin')
                      _buildMenuItem(
                        Icons.admin_panel_settings,
                        "Admin Panel",
                        context,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminPanelPage(),
                            ),
                          );
                        },
                      ),
                    _buildMenuItem(
                      Icons.lock_outline,
                      "Change Password",
                      context,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangePasswordPage(),
                          ),
                        );
                      },
                    ),
                    if (_role == 'admin')
                      _buildMenuItem(
                        Icons.business_center,
                        "Handle Business",
                        context,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HandleBusinessPage(),
                            ),
                          );
                        },
                      ),
                    _buildMenuItem(Icons.logout, "Log Out", context, () async {
                      await UserPresenceService.markCurrentUserOffline();
                      await FirebaseAuth.instance.signOut();
                      await GoogleSignIn().signOut();
                      // Add a check to ensure the widget is still mounted before using its context.
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => GetStart()),
                        (route) => false,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildMenuItem(
    IconData icon,
    String title,
    BuildContext context,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        onTap: onTap,
      ),
    );
  }
}
