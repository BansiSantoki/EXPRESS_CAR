import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserPresenceService {
  UserPresenceService._();

  static String? _lastUid;
  static DateTime? _lastOnlineWriteAt;

  static Future<void> markCurrentUserOnline({User? user}) async {
    final effectiveUser = user ?? FirebaseAuth.instance.currentUser;
    if (effectiveUser == null) return;

    final now = DateTime.now();
    if (_lastUid == effectiveUser.uid && _lastOnlineWriteAt != null) {
      final elapsed = now.difference(_lastOnlineWriteAt!);
      if (elapsed.inSeconds < 30) {
        return;
      }
    }

    _lastUid = effectiveUser.uid;
    _lastOnlineWriteAt = now;

    final updates = <String, dynamic>{
      'isOnline': true,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'presenceUpdatedAt': FieldValue.serverTimestamp(),
    };

    final email = effectiveUser.email?.trim();
    if (email != null && email.isNotEmpty) {
      updates['email'] = email;
    }

    final displayName = effectiveUser.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      updates['displayName'] = displayName;
    }

    final photoURL = effectiveUser.photoURL?.trim();
    if (photoURL != null && photoURL.isNotEmpty) {
      updates['photoURL'] = photoURL;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(effectiveUser.uid)
        .set(updates, SetOptions(merge: true));
  }

  static Future<void> markCurrentUserOffline({User? user}) async {
    final effectiveUser = user ?? FirebaseAuth.instance.currentUser;
    if (effectiveUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(effectiveUser.uid)
        .set({
          'isOnline': false,
          'lastSeenAt': FieldValue.serverTimestamp(),
          'presenceUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
