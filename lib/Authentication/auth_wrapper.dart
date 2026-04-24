import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:express_car/HomeDetails/Home_Page/home_page.dart';
import 'package:express_car/Splash/get_start.dart';
import 'package:express_car/Authentication/CompleteProfile.dart';
import 'package:express_car/theme/app_theme.dart';
import 'package:express_car/services/user_presence_service.dart';

// new admin panel
import 'package:express_car/Admin/admin_panel.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  static const Duration _firestoreTimeout = Duration(seconds: 8);

  Future<bool> _isProfileComplete(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(_firestoreTimeout);

      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      // Check if all required profile fields are present
      return (data['phone'] != null &&
          data['address'] != null &&
          data['dob'] != null &&
          data['gender'] != null);
    } catch (_) {
      return false;
    }
  }

  Future<String> _resolveUserRole(User user) async {
    try {
      await UserPresenceService.markCurrentUserOnline(
        user: user,
      ).timeout(_firestoreTimeout);
    } catch (_) {
      // Presence update failure should not block navigation.
    }

    await _createUserDocumentIfNeeded(user);

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .timeout(_firestoreTimeout);

    if (!doc.exists) {
      return 'user';
    }

    final data = doc.data();
    if (data == null) {
      return 'user';
    }

    return (data['role'] ?? 'user') as String;
  }

  Future<void> _createUserDocumentIfNeeded(User user) async {
    try {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc
            .set({
              "displayName": user.displayName ?? "",
              "email": user.email ?? "",
              "photoURL": user.photoURL ?? "",
              "favorites": [],
              "createdAt": DateTime.now(),
              // add default role field so we can distinguish normal users from admins
              "role": "user",
            })
            .timeout(_firestoreTimeout);
      }
    } catch (_) {
      // Ignore bootstrap write errors to avoid breaking auth navigation.
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.canvas,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          return FutureBuilder<dynamic>(
            future:
                Future.wait([
                  _resolveUserRole(user),
                  _isProfileComplete(user),
                ]).timeout(
                  const Duration(seconds: 10),
                  onTimeout: () => ['user', true],
                ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const Scaffold(
                  body: Center(child: Text('Error loading user data')),
                );
              }

              final role = snapshot.data?[0] ?? 'user';
              final profileComplete = snapshot.data?[1] ?? false;

              if (role == 'admin') {
                return const AdminPanelPage();
              } else if (!profileComplete) {
                return const CompleteProfilePage();
              } else {
                return HomePage();
              }
            },
          );
        }

        return const GetStart();
      },
    );
  }
}
