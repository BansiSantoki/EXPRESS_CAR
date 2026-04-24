import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageUsersPage extends StatelessWidget {
  const ManageUsersPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final docs = snapshot.data!.docs;
          final totalUsers = docs.length;
          final totalAdmins = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['role'] ?? 'user').toString() == 'admin';
          }).length;
          final totalOnline = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['isOnline'] == true;
          }).length;

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    'Total Users: $totalUsers  |  Admins: $totalAdmins  |  Logged In: $totalOnline',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final role = (data['role'] ?? 'user') as String;
                      final displayName =
                          data['displayName'] ?? data['email'] ?? 'N/A';
                      final email = (data['email'] ?? '').toString();
                      final uid = docs[index].id;
                      final isOnline = data['isOnline'] == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(displayName.toString()),
                          subtitle: Text(
                            'Email: $email\nUID: $uid\nStatus: ${isOnline ? 'Online' : 'Offline'}',
                          ),
                          isThreeLine: true,
                          trailing: DropdownButton<String>(
                            value: role,
                            items: const [
                              DropdownMenuItem(
                                value: 'user',
                                child: Text('User'),
                              ),
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('Admin'),
                              ),
                            ],
                            onChanged: (newRole) {
                              if (newRole == null) return;
                              docs[index].reference.update({'role': newRole});
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
