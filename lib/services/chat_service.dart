import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/message.dart';

// Unread totals for one conversation partner, derived straight from the
// message documents so a single source of truth backs the chat list badge.
class UnreadSummary {
  final int count;
  final DateTime latestAt;

  const UnreadSummary({required this.count, required this.latestAt});
}

// Cloud Firestore backend for Lab Activity 6 (Firebase Part II).
class ChatService {
  // `late final` resolves the platform channel on first use instead of
  // during construction, so screens can catch a missing Firebase
  // configuration and show an error state instead of crashing.
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Real-time list of every registered profile in the "Users"
  // collection. Each map carries whatever UserService saved
  // (uid, email, username, firstName, lastName, image) plus docId.
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection('Users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
        user['docId'] = doc.id;
        return user;
      }).toList();
    });
  }

  // Real-time unread totals for the signed-in user, keyed by the uid of
  // whoever sent them. One collection-group listener serves the whole
  // chat list instead of one listener per user, and Firestore only ships
  // messages addressed to this user that are still unread, so the stream
  // stays tiny as conversations are opened.
  Stream<Map<String, UnreadSummary>> getUnreadSummariesStream() {
    final me = _firebaseAuth.currentUser?.uid;

    if (me == null || me.isEmpty) {
      return Stream.value(<String, UnreadSummary>{});
    }

    return _firestore
        .collectionGroup('messages')
        .where('receiverId', isEqualTo: me)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final summaries = <String, UnreadSummary>{};

      for (final doc in snapshot.docs) {
        final message = MessageModel.fromMap(doc.data());
        final sender = message.senderId;

        // Messages I sent myself are never unread for me.
        if (sender.isEmpty || sender == me) continue;

        final sentAt = message.timestamp.toDate();
        final previous = summaries[sender];

        summaries[sender] = UnreadSummary(
          count: (previous?.count ?? 0) + 1,
          latestAt: previous == null || sentAt.isAfter(previous.latestAt)
              ? sentAt
              : previous.latestAt,
        );
      }

      return summaries;
    });
  }

  // Marks the messages this conversation partner sent to me as read.
  // Only documents with isRead == false are written (messages stored
  // before the field existed are left alone), only the other user's
  // messages are touched, and large unread streaks are committed in
  // batches of 500 - Firestore's per-batch limit.
  Future<void> markMessagesAsRead(String otherUserId) async {
    final me = _firebaseAuth.currentUser?.uid;
    final other = otherUserId.trim();

    if (me == null || me.isEmpty || other.isEmpty || other == me) return;

    final room = _firestore
        .collection('chat_rooms')
        .doc(_buildChatRoomId(me, other))
        .collection('messages');

    final unread =
        await room.where('isRead', isEqualTo: false).get();

    final targets = unread.docs
        .where((doc) => (doc.data()['senderId'] ?? '').toString() == other)
        .toList();

    for (var start = 0; start < targets.length; start += 500) {
      final batch = _firestore.batch();

      for (final doc in targets.skip(start).take(500)) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    }
  }

  // Deterministic chat room id: both UIDs are sorted before joining, so
  // the same pair of users always produces exactly one room, no matter
  // who started the conversation first.
  String _buildChatRoomId(String userId1, String userId2) {
    return buildChatRoomId(userId1, userId2);
  }

  // The same rule, exposed so tests can prove that both users always
  // agree on a room id without needing a Firebase session.
  @visibleForTesting
  static String buildChatRoomId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return ids.join('_');
  }

  // Stores one message in chat_rooms/{chatRoomId}/messages.
  // Empty / whitespace-only messages are ignored and a missing Firebase
  // session is reported instead of crashing.
  Future<void> sendMessage(String receiverId, String message) async {
    final text = message.trim();

    if (text.isEmpty) return;

    final currentUser = _firebaseAuth.currentUser;

    if (currentUser == null) {
      throw Exception('No signed-in user found. Please sign in again.');
    }

    final receiver = receiverId.trim();

    if (receiver.isEmpty) return;

    final MessageModel newMessage = MessageModel(
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? '',
      receiverId: receiver,
      message: text,
      timestamp: Timestamp.now(),
      // Unread for the receiver until they open this conversation.
      isRead: false,
    );

    final chatRoomId = _buildChatRoomId(currentUser.uid, receiver);

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(newMessage.toMap());
  }

  // Real-time message stream for one pair of users, newest first.
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessage(
    String currentUserId,
    String otherUserId,
  ) {
    final chatRoomId = _buildChatRoomId(currentUserId, otherUserId);

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Firebase Auth uid stored behind an email address, or null when no
  // Users document matches that email.
  Future<String?> getUidByEmail(String email) async {
    final query = await _firestore
        .collection('Users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final data = query.docs.first.data();

    // Profiles are saved with the uid as their document id, so the uid
    // field and the document id always point to the same value.
    return (data['uid'] ?? query.docs.first.id).toString();
  }
}
