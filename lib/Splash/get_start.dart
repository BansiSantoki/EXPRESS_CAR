import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:express_car/Authentication/signup_page.dart';
import 'package:express_car/Authentication/signin_page.dart';
import 'package:express_car/theme/app_theme.dart';

class GetStart extends StatefulWidget {
  const GetStart({super.key});

  @override
  State<GetStart> createState() => _GetStartState();
}

class _GetStartState extends State<GetStart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Futures for optimized database queries
  late Future<int> _carsCountFuture;
  late Future<int> _usersCountFuture;
  late Future<double> _ratingFuture;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();

    // Initialize the futures once so they don't re-fetch on UI rebuilds
    _carsCountFuture = _getCarsCount();
    _usersCountFuture = _getUsersCount();
    _ratingFuture = _getAverageRating();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 🚀 OPTIMIZATION: Use server-side count() instead of downloading all documents
  Future<int> _getCarsCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('cars')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint("Error fetching cars count: $e");
      return 0;
    }
  }

  // 🚀 OPTIMIZATION: Use server-side count() instead of downloading all documents
  Future<int> _getUsersCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint("Error fetching users count: $e");
      return 0;
    }
  }

  // 🚀 OPTIMIZATION: Use server-side aggregate() to calculate weighted average
  Future<double> _getAverageRating() async {
    try {
      // In Dart, sum() is a top-level function exported by cloud_firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('cars')
          .aggregate(sum('rating_total'), sum('review_count'))
          .get();

      // Extract the values using getSum()
      final totalScore = snapshot.getSum('rating_total') ?? 0.0;
      final totalReviews = snapshot.getSum('review_count') ?? 0.0;

      if (totalReviews == 0) return 0.0;
      return totalScore / totalReviews;
    } catch (e) {
      debugPrint("Error fetching average rating: $e");
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE7F3FF), Color(0xFFFDFEFF), Color(0xFFFFF3EA)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        width: 156,
                        height: 156,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0A6EBD), Color(0xFF0A4F8E)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF0A6EBD,
                              ).withValues(alpha: 0.32),
                              blurRadius: 34,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.electric_car_rounded,
                          size: 74,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 38),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          Text(
                            'Express Car',
                            style: textTheme.headlineLarge?.copyWith(
                              fontSize: 42,
                              color: AppTheme.ink,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Smarter Rental, Faster Roads',
                            style: textTheme.titleLarge?.copyWith(
                              color: AppTheme.primary,
                              fontSize: 22,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Compare cars, track bookings, manage favorites, and ride with confidence from one polished app.',
                        style: textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildFutureIntBadge(
                          future: _carsCountFuture,
                          label: 'Cars',
                        ),
                        Container(width: 1, height: 38, color: AppTheme.border),
                        _buildFutureIntBadge(
                          future: _usersCountFuture,
                          label: 'Users',
                        ),
                        Container(width: 1, height: 38, color: AppTheme.border),
                        _buildFutureRatingBadge(
                          future: _ratingFuture,
                          label: 'Rating',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignUpPage(),
                            ),
                          );
                        },
                        child: const Text('Create Account'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignInPage(),
                            ),
                          );
                        },
                        child: const Text('Sign In'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFutureIntBadge({
    required Future<int> future,
    required String label,
  }) {
    return FutureBuilder<int>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildBadge("...", label);
        }
        final count = snapshot.data ?? 0;
        return _buildBadge(_formatCompactCount(count), label);
      },
    );
  }

  Widget _buildFutureRatingBadge({
    required Future<double> future,
    required String label,
  }) {
    return FutureBuilder<double>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildBadge("...", label);
        }
        final rating = snapshot.data ?? 0.0;
        return _buildBadge(rating.toStringAsFixed(1), label);
      },
    );
  }

  String _formatCompactCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M+';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k+';
    }
    return count.toString();
  }
}
