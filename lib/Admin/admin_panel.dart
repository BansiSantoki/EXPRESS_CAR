import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:express_car/Handle_Car/Manage_Booking.dart';
import 'package:express_car/Handle_Car/Add_Car.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:express_car/theme/app_theme.dart';
import 'package:express_car/services/user_presence_service.dart';

import '../Handle_Car/Manage_Cars.dart';
import '../Splash/get_start.dart';
import 'manage_users.dart';
import 'driver_management_page.dart';
import 'app_settings_page.dart'; // 🚀 IMPORT ADDED

enum _AdminUserSheetMode { total, loggedIn }

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  int _selectedIndex = 0;

  Stream<int> _countCollection(String collection) {
    return FirebaseFirestore.instance
        .collection(collection)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<int> _countOnlineUsers() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _onlineUsersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _allUsersStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate().toLocal();
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  bool _matchesSearch(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    final data = doc.data();
    final email = (data['email'] ?? '').toString().toLowerCase();
    final uid = doc.id.toLowerCase();
    return email.contains(normalized) || uid.contains(normalized);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _collectionStream(
    String collection,
  ) {
    return FirebaseFirestore.instance.collection(collection).snapshots();
  }

  DateTime? _readTimestamp(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value != null) {
        final parsed = DateTime.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortByLatestTimestamp(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    List<String> keys,
  ) {
    final sorted = [...docs];
    sorted.sort((a, b) {
      final aTime =
          _readTimestamp(a.data(), keys) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          _readTimestamp(b.data(), keys) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  String _displayText(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Future<void> _handleLogout() async {
    await UserPresenceService.markCurrentUserOffline();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const GetStart()),
      (route) => false,
    );
  }

  void _onNavTapped(int index) async {
    if (_selectedIndex == index) return;

    setState(() => _selectedIndex = index);

    // Add a smooth delay to let the selection animation play before pushing the route
    await Future.delayed(const Duration(milliseconds: 250));

    Widget page;
    if (index == 1) {
      page = const ManageUsersPage();
    } else if (index == 2) {
      page = const ManageCarsPage();
    } else if (index == 3) {
      page = const ManageBookingsPage();
    } else if (index == 4) {
      page = const DriverManagementPage();
    } else {
      return; // Home
    }

    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    // When returning from the pushed page, smoothly animate back to the Home tab
    if (mounted) {
      setState(() => _selectedIndex = 0);
    }
  }

  Widget _buildLiveSectionHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppTheme.primarySoft,
          child: Icon(icon, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveFeedCard({
    required String collection,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> timestampKeys,
    required String emptyMessage,
    required Widget Function(
      BuildContext context,
      Map<String, dynamic> data,
      String docId,
    )
    itemBuilder,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLiveSectionHeader(title, subtitle, icon),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _collectionStream(collection),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Unable to load live data.',
                    style: TextStyle(color: AppTheme.accent),
                  ),
                );
              }

              final docs = _sortByLatestTimestamp(
                snapshot.data?.docs ?? [],
                timestampKeys,
              );

              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                );
              }

              final previewDocs = docs.take(5).toList();

              return Column(
                children: previewDocs
                    .map((doc) => itemBuilder(context, doc.data(), doc.id))
                    .map(
                      (child) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: child,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showUsersSheet(BuildContext context, _AdminUserSheetMode mode) {
    final isTotal = mode == _AdminUserSheetMode.total;
    final title = isTotal ? 'All Users' : 'Logged In Users';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        var searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  height: MediaQuery.of(sheetContext).size.height * 0.72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.ink,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by email or UID',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: const Color(0xFFF4F6FA),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _allUsersStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (snapshot.hasError) {
                              return const Center(
                                child: Text(
                                  'Unable to load users.',
                                  style: TextStyle(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }

                            final docs = (snapshot.data?.docs ?? [])
                                .where(
                                  (doc) => _matchesSearch(doc, searchQuery),
                                )
                                .toList();
                            if (docs.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No users found for this search.',
                                  style: TextStyle(color: Color(0xFF6B7280)),
                                ),
                              );
                            }

                            final onlineDocs = docs.where((doc) {
                              final data = doc.data();
                              return data['isOnline'] == true;
                            }).toList();

                            final historyDocs =
                                docs.where((doc) {
                                  final data = doc.data();
                                  return data['lastLoginAt'] != null ||
                                      data['lastSeenAt'] != null;
                                }).toList()..sort((a, b) {
                                  final aDate =
                                      (a.data()['lastLoginAt'] is Timestamp)
                                      ? (a.data()['lastLoginAt'] as Timestamp)
                                            .toDate()
                                      : DateTime.fromMillisecondsSinceEpoch(0);
                                  final bDate =
                                      (b.data()['lastLoginAt'] is Timestamp)
                                      ? (b.data()['lastLoginAt'] as Timestamp)
                                            .toDate()
                                      : DateTime.fromMillisecondsSinceEpoch(0);
                                  return bDate.compareTo(aDate);
                                });

                            if (isTotal) {
                              return ListView.separated(
                                itemCount: docs.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 10),
                                itemBuilder: (context, index) {
                                  final doc = docs[index];
                                  final data = doc.data();
                                  final email = (data['email'] ?? 'No email')
                                      .toString();
                                  final role = (data['role'] ?? 'user')
                                      .toString();
                                  final isOnline = data['isOnline'] == true;

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: isOnline
                                          ? const Color(0xFFDDF6E8)
                                          : const Color(0xFFEFF3F9),
                                      child: Icon(
                                        isOnline
                                            ? Icons.circle
                                            : Icons.person_outline,
                                        size: isOnline ? 12 : 18,
                                        color: isOnline
                                            ? const Color(0xFF22A064)
                                            : const Color(0xFF3B82F6),
                                      ),
                                    ),
                                    title: Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Role: $role • ${isOnline ? 'Online' : 'Offline'}',
                                    ),
                                  );
                                },
                              );
                            }

                            return ListView(
                              children: [
                                const Text(
                                  'Currently Online',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (onlineDocs.isEmpty)
                                  const Text(
                                    'No users online right now.',
                                    style: TextStyle(color: Color(0xFF6B7280)),
                                  )
                                else
                                  ...onlineDocs.map((doc) {
                                    final data = doc.data();
                                    final email = (data['email'] ?? 'No email')
                                        .toString();
                                    final role = (data['role'] ?? 'user')
                                        .toString();

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.circle,
                                        size: 10,
                                        color: Color(0xFF22A064),
                                      ),
                                      title: Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Text('Role: $role'),
                                    );
                                  }),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                const Text(
                                  'Login History (Old + Current)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (historyDocs.isEmpty)
                                  const Text(
                                    'No login history found.',
                                    style: TextStyle(color: Color(0xFF6B7280)),
                                  )
                                else
                                  ...historyDocs.map((doc) {
                                    final data = doc.data();
                                    final email = (data['email'] ?? 'No email')
                                        .toString();
                                    final lastLogin = _formatTimestamp(
                                      data['lastLoginAt'],
                                    );
                                    final lastSeen = _formatTimestamp(
                                      data['lastSeenAt'],
                                    );

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Last login: $lastLogin\nLast seen: $lastSeen',
                                      ),
                                      isThreeLine: true,
                                    );
                                  }),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onNavTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 12 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primary : Colors.white70,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Admin Control Center'),
        actions: [
          // 🚀 NEW: Settings Button
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.ink),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppSettingsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      // Floating Action Button for primary action
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddCarPage()),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text(
          'Add Car',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      // Futuristic Floating Bottom Navigation Bar
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          height: 65,
          decoration: BoxDecoration(
            color: const Color(0xFF121319),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.dashboard_rounded, 'Home'),
              _buildNavItem(1, Icons.people_alt_rounded, 'Users'),
              _buildNavItem(2, Icons.directions_car_rounded, 'Cars'),
              _buildNavItem(3, Icons.calendar_month_rounded, 'Bookings'),
              _buildNavItem(4, Icons.badge_rounded, 'Fleet'),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            80,
          ), // Extra padding for FAB/Nav
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A6EBD), Color(0xFF0A4F8E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Manage users, cars, and bookings with live stats.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _CountCard(
                      title: 'Total Users',
                      icon: Icons.people_alt_outlined,
                      countStream: _countCollection('users'),
                      onTap: () =>
                          _showUsersSheet(context, _AdminUserSheetMode.total),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CountCard(
                      title: 'Logged In',
                      icon: Icons.person_pin_circle_outlined,
                      countStream: _countOnlineUsers(),
                      onTap: () => _showUsersSheet(
                        context,
                        _AdminUserSheetMode.loggedIn,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CountCard(
                      title: 'Cars',
                      icon: Icons.directions_car_outlined,
                      countStream: _countCollection('cars'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageCarsPage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CountCard(
                      title: 'Bookings',
                      icon: Icons.assignment_turned_in_outlined,
                      countStream: _countCollection('bookings'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageBookingsPage(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CountCard(
                      title: 'Fleet Docs',
                      icon: Icons.badge_outlined,
                      countStream: _countCollection('driver_documents'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DriverManagementPage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CountCard(
                      title: 'Fleet Items',
                      icon: Icons.directions_car_filled_outlined,
                      countStream: _countCollection('fleet_items'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DriverManagementPage(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildLiveFeedCard(
                collection: 'users',
                title: 'Live Users',
                subtitle:
                    'Newest profiles, roles, and presence status from Firebase.',
                icon: Icons.people_alt_outlined,
                timestampKeys: const [
                  'lastLoginAt',
                  'lastSeenAt',
                  'createdAt',
                  'updatedAt',
                  'presenceUpdatedAt',
                ],
                emptyMessage: 'No user documents yet.',
                itemBuilder: (context, data, docId) {
                  final email = _displayText(
                    data['email'],
                    fallback: 'No email',
                  );
                  final role = _displayText(data['role'], fallback: 'user');
                  final isOnline = data['isOnline'] == true;
                  final displayName = _displayText(
                    data['displayName'],
                    fallback: email,
                  );

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isOnline
                              ? const Color(0xFFDDF6E8)
                              : const Color(0xFFEFF3F9),
                          child: Icon(
                            isOnline ? Icons.circle : Icons.person_outline,
                            size: isOnline ? 12 : 18,
                            color: isOnline
                                ? const Color(0xFF22A064)
                                : const Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$email • $role',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: isOnline
                                ? const Color(0xFF22A064)
                                : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _buildLiveFeedCard(
                collection: 'cars',
                title: 'Live Cars',
                subtitle: 'Fresh car listings saved from the admin add form.',
                icon: Icons.directions_car_outlined,
                timestampKeys: const ['created_at', 'updated_at', 'updatedAt'],
                emptyMessage: 'No cars have been added yet.',
                itemBuilder: (context, data, docId) {
                  final name = _displayText(
                    data['name'],
                    fallback: 'Untitled car',
                  );
                  final model = _displayText(data['model']);
                  final type = _displayText(data['type']);
                  final price = data['price_per_day'] ?? data['price'];
                  final ownerEmail = _displayText(data['owner_email']);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primarySoft,
                          child: const Icon(
                            Icons.directions_car,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (model != '-') model,
                                  if (type != '-') type,
                                ].join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Owner: $ownerEmail',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Rs ${_displayText(price)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _buildLiveFeedCard(
                collection: 'bookings',
                title: 'Live Bookings',
                subtitle:
                    'Recent bookings and payment status straight from Firebase.',
                icon: Icons.assignment_turned_in_outlined,
                timestampKeys: const [
                  'created_at',
                  'createdAt',
                  'updated_at',
                  'updatedAt',
                  'paid_at',
                  'payment_time',
                ],
                emptyMessage: 'No bookings have been created yet.',
                itemBuilder: (context, data, docId) {
                  final bookingId = _displayText(
                    data['booking_id'],
                    fallback: docId,
                  );
                  final carName = _displayText(
                    data['car_name'],
                    fallback: 'Unknown car',
                  );
                  final userEmail = _displayText(
                    data['user_mail'] ?? data['user_email'],
                    fallback: 'Unknown user',
                  );
                  final paymentStatus = _displayText(
                    data['payment_status'],
                    fallback: 'pending',
                  );
                  final totalAmount = _displayText(
                    data['total_amount'],
                    fallback: '0',
                  );

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFEFF3F9),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$bookingId • $carName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                userEmail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs $totalAmount',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              paymentStatus.toUpperCase(),
                              style: TextStyle(
                                color: paymentStatus.toLowerCase() == 'paid'
                                    ? const Color(0xFF22A064)
                                    : const Color(0xFFD97706),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Text(
                'Active User IDs',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _onlineUsersStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return const Text(
                        'Unable to load active users.',
                        style: TextStyle(color: AppTheme.accent),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Text(
                        'No users are currently logged in.',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final uid = docs[index].id;
                        final email = (data['email'] ?? '').toString();
                        final role = (data['role'] ?? 'user').toString();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UID: $uid',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email.isNotEmpty ? '$email ($role)' : role,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.title,
    required this.icon,
    required this.countStream,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Stream<int> countStream;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primarySoft,
              child: Icon(icon, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<int>(
                stream: countStream,
                builder: (context, snapshot) {
                  final hasError = snapshot.hasError;
                  final count = snapshot.data ?? 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasError ? '-' : '$count',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
