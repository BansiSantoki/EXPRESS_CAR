import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:express_car/Authentication/auth_wrapper.dart';
import 'package:express_car/Splash/get_start.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../firebase_options.dart';
import 'signup_page.dart';
import 'enter_email.dart';
import 'admin_login_page.dart';

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  static const Color _mint = Color(0xFF3FE48D);
  static const Color _mintDark = Color(0xFF20C26D);
  static const Color _ink = Color(0xFF0E0F14);
  static const Color _surface = Color(0xFFF3F4F6);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final user = userCredential.user;

      if (user != null) {
        await _upsertUserDoc(user);
        if (!mounted) return;
        // Navigate to AuthWrapper to check email verification and role
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Try again.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email.';
          break;
        default:
          message = 'Login failed: ${e.message}';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isSubmitting = true);
    try {
      final GoogleSignIn googleSignIn = _buildGoogleSignInClient();

      // Ensure stale account selection does not break the next attempt.
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user != null) {
        await _upsertUserDoc(user);
        if (!mounted) return;
        // Navigate to AuthWrapper to check email verification and role
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_googleAuthErrorMessage(e.code, e.message))),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_googlePlatformErrorMessage(e.code, e.message))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  GoogleSignIn _buildGoogleSignInClient() {
    if (kIsWeb) {
      return GoogleSignIn(scopes: const ['email', 'profile']);
    }

    return GoogleSignIn();
  }

  String _googleAuthErrorMessage(String code, String? message) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'This email is already registered with another sign-in method.';
      case 'invalid-credential':
        return 'Invalid Google credential. Please try again.';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled in Firebase Authentication.';
      case 'network-request-failed':
        return 'Network error. Check internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return 'Google sign-in failed: ${message ?? code}';
    }
  }

  String _googlePlatformErrorMessage(String code, String? message) {
    final raw = (message ?? '').toLowerCase();

    if (code == 'sign_in_canceled') {
      return 'Google sign-in canceled.';
    }

    if (code == 'network_error' || raw.contains('network')) {
      return 'Network issue while connecting to Google. Please retry.';
    }

    if (raw.contains('apiexception: 10') || raw.contains('developer error')) {
      return 'Google configuration error (ApiException 10). Add SHA-1/SHA-256 in Firebase for this app and re-download google-services.json.';
    }

    return 'Google sign-in failed: ${message ?? code}';
  }

  Future<void> _upsertUserDoc(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();
    final data = doc.data();

    final email = (user.email ?? data?['email']?.toString() ?? '').trim();
    final emailName = email.contains('@') ? email.split('@').first.trim() : '';
    final resolvedName =
        (data?['displayName'] ??
                data?['name'] ??
                data?['fullName'] ??
                user.displayName ??
                emailName)
            .toString()
            .trim();

    final payload = <String, dynamic>{
      'email': email,
      'displayName': resolvedName.isEmpty ? 'Guest User' : resolvedName,
      'photoURL': (data?['photoURL'] ?? user.photoURL ?? '').toString().trim(),
      'role': (data?['role'] ?? 'user').toString(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!doc.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      payload['favorites'] = <String>[];
    }

    await docRef.set(payload, SetOptions(merge: true));
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
                children: [
                  Container(
                    height: size.height * 0.34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF15171E), Color(0xFF0A0B10)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -10,
                    top: -22,
                    child: Container(
                      width: 140,
                      height: 140,
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
                          MaterialPageRoute(builder: (context) => GetStart()),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cardez',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Find the ideal car rental for your trip',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.22,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Global deals, premium rides, seamless booking.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 24,
                    child: Image.asset(
                      'assets/images/1car.jpg',
                      height: size.height * 0.17,
                      fit: BoxFit.contain,
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
                  boxShadow: [
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
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Welcome back',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Login to continue your road journey',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: _fieldDecoration(
                          label: 'Email',
                          hint: 'example@gmail.com',
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
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
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
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ForgotPasswordPage(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: _mintDark,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _signIn,
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
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: _ink,
                                  ),
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.black.withValues(alpha: 0.12),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or continue with',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.45),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.black.withValues(alpha: 0.12),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _signInWithGoogle,
                          icon: Image.asset(
                            'assets/images/google.jpg',
                            width: 20,
                            height: 20,
                          ),
                          label: const Text(
                            'Sign in with Google',
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.black.withValues(alpha: 0.12),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.55),
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SignUpPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: _mintDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminLoginPage(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: _ink,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Admin Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
