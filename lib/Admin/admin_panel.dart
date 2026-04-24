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

enum _AdminUserSheetMode { total, loggedIn }

class AdminPanelPage extends StatelessWidget {
  const AdminPanelPage({super.key});

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

  Stream<int> _countUsersWithLoginHistory() {
    return _allUsersStream().map(
      (snapshot) => snapshot.docs.where((doc) {
        final data = doc.data();
        return data['lastLoginAt'] != null || data['lastSeenAt'] != null;
      }).length,
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: const Text('Admin Control Center')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CountCard(
                      title: 'Bookings',
                      icon: Icons.assignment_turned_in_outlined,
                      countStream: _countCollection('bookings'),
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
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CountCard(
                      title: 'Fleet Items',
                      icon: Icons.directions_car_filled_outlined,
                      countStream: _countCollection('fleet_items'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
              const Text(
                'Admin Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.add_circle_outline,
                title: 'Add Car',
                subtitle: 'Create a new car listing with ImgBB images.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddCarPage()),
                  );
                },
              ),
              _ActionTile(
                icon: Icons.manage_accounts,
                title: 'Manage Users',
                subtitle: 'Promote users to admin or update roles.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageUsersPage()),
                  );
                },
              ),
              _ActionTile(
                icon: Icons.car_rental,
                title: 'Manage Cars',
                subtitle: 'Review and control listed cars.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageCarsPage()),
                  );
                },
              ),
              _ActionTile(
                icon: Icons.calendar_month,
                title: 'Manage Bookings',
                subtitle: 'Track all booking records.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManageBookingsPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    await UserPresenceService.markCurrentUserOffline();
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const GetStart()),
                      (route) => false,
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primarySoft,
          child: Icon(icon, color: AppTheme.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}
