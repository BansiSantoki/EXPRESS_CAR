import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:express_car/Splash/get_start.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:express_car/theme/app_theme.dart';
import '../firebase_options.dart';
import 'auth_wrapper.dart';
import 'signup_page.dart';
import 'enter_email.dart';
import 'admin_login_page.dart';
import 'package:express_car/services/user_presence_service.dart';

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final Color _primaryColor = AppTheme.primary;
  @override
  void initState() {
    super.initState();
    _checkAutoLogin();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
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
    _animationController.dispose();
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _upsertUserDoc(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final existing = await docRef.get();
    final existingData = existing.data();
    final existingRole = (existingData?['role'] ?? 'user') as String;
    final payload = <String, dynamic>{
      'email': user.email ?? '',
      'displayName': user.displayName ?? '',
      'photoURL': user.photoURL ?? '',
      'favorites': [],
      'role': existingRole,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'isOnline': true,
      'presenceUpdatedAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(payload, SetOptions(merge: true));
    await UserPresenceService.markCurrentUserOnline(user: user);
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isSubmitting = true);
    try {
      final GoogleSignIn googleSignIn = _buildGoogleSignInClient();

      // Ensure we always start from a clean Google session.
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
      // Web uses Firebase web setup; avoid forcing iOS client id.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const GetStart()),
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: _primaryColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sign in to your account to continue",
                  style: TextStyle(
                    fontSize: 15,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: InputDecoration(
                              labelText: "Email Address",
                              hintText: "your@email.com",
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: _primaryColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppTheme.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty)
                                return 'Please enter your email';
                              final emailRegex = RegExp(
                                r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                              );
                              if (!emailRegex.hasMatch(value))
                                return 'Please enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: InputDecoration(
                              labelText: "Password",
                              hintText: "••••••••",
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: _primaryColor,
                              ),
                              suffixIcon: GestureDetector(
                                onTap: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: _primaryColor,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty)
                                return 'Please enter your password';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                disabledBackgroundColor: Colors.grey[300],
                              ),
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.grey[400]!,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      "Sign In",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: Colors.grey[300], thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "Or continue with",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: Colors.grey[300], thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          "assets/images/google.jpg",
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Sign in with Google",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SignUpPage()),
                        );
                      },
                      child: Text(
                        "Sign Up",
                        style: TextStyle(
                          fontSize: 14,
                          color: _primaryColor,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminLoginPage(),
                        ),
                      );
                    },
                    child: Text(
                      "Admin Login",
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
