import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:express_car/Admin/admin_panel.dart';
import 'package:express_car/theme/app_theme.dart';
import 'package:express_car/services/user_presence_service.dart';
import 'signin_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  static const String _fixedAdminEmail = 'admin@expresscar.com';
  static const String _fixedAdminPassword = 'Admin@12345';
  static const Color _mintDark = Color(0xFF1D4ED8);
  static const Color _mint = Color(0xFF3B82F6);
  static const Color _ink = Color(0xFF0E0F14);
  static const Color _surface = Color(0xFFF3F4F6);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _adminLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final enteredEmail = _emailController.text.trim().toLowerCase();
      final enteredPassword = _passwordController.text.trim();

      if (enteredEmail != _fixedAdminEmail ||
          enteredPassword != _fixedAdminPassword) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Admin Panel is fixed: use configured admin email/password only.',
            ),
          ),
        );
        return;
      }

      UserCredential userCredential;
      try {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _fixedAdminEmail,
          password: _fixedAdminPassword,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'user-not-found' && e.code != 'invalid-credential') {
          rethrow;
        }

        // First-time setup: create fixed admin account.
        userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _fixedAdminEmail,
              password: _fixedAdminPassword,
            );
      }

      final user = userCredential.user;
      if (user == null) {
        throw Exception('No user returned');
      }

      // Keep fixed admin record visible in Firestore.
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
          
      await docRef.set({
        'displayName': user.displayName ?? 'Admin',
        'email': user.email ?? _fixedAdminEmail,
        'photoURL': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'presenceUpdatedAt': FieldValue.serverTimestamp(),
        'role': 'admin',
      }, SetOptions(merge: true));
      
      await UserPresenceService.markCurrentUserOnline(user: user);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminPanelPage()),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect password. Try again.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email.';
          break;
        default:
          message = 'Admin login failed: ${e.message}';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children:[
                  Container(
                    height: size.height * 0.31,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors:[Color(0xFF15171E), Color(0xFF090A0F)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -14,
                    top: -18,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(34),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => SignInPage()),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 22,
                    top: 74,
                    child: Icon(Icons.security_rounded, color: _mint, size: 36),
                  ),
                  Positioned(
                    left: 22,
                    right: 20,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:[
                        const Text(
                          'Admin Access',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Use fixed credentials to unlock control panel',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.74),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow:[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children:[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FBF8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _mintDark.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Allowed admin email: admin@expresscar.com',
                          style: TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: _fieldDecoration(
                          label: 'Admin Email',
                          hint: 'admin@expresscar.com',
                          icon: Icons.alternate_email_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          final emailRegex = RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
                          );
                          if (!emailRegex.hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration:
                            _fieldDecoration(
                              label: 'Password',
                              hint: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: _mintDark,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _adminLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mint,
                            foregroundColor: _ink,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _ink,
                                  ),
                                )
                              : const Text(
                                  'Access Admin Panel',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.07),
                          ),
                        ),
                        child: Row(
                          children:[
                            const Icon(
                              Icons.verified_user,
                              size: 18,
                              color: _mintDark,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Only authenticated admins can access this panel.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => SignInPage()),
                  );
                },
                child: const Text(
                  'Back to User Login',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8F8FA),
      prefixIcon: Icon(icon, color: _mintDark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: _mintDark, width: 1.5),
      ),
      labelStyle: TextStyle(color: Colors.black.withValues(alpha: 0.65)),
      hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.35)),
    );
  }
}