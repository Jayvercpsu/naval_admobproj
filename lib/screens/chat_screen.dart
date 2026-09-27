import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/chat_service.dart';
import '../widgets/custom_text.dart';
import 'chat_detailscreen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchChatController = TextEditingController();
  final ChatService _chatService = ChatService();

  // Subscribed once in initState: rebuilding the screen (every search
  // keystroke) must not open another Firestore listener.
  Stream<List<Map<String, dynamic>>>? _usersStream;

  // Same rule for unread totals: one listener for the whole list, never
  // one per user row.
  Stream<Map<String, UnreadSummary>>? _unreadStream;

  String? _currentUserId;
  String? _currentUserEmail;
  String _searchText = '';

  // Image urls that failed to decode or load. Their rows drop back to the
  // initials child instead of re-creating a provider that will fail again.
  final Set<String> _brokenImageUrls = {};

  // The unread listener error is reported once, not on every keystroke.
  bool _unreadErrorReported = false;

  @override
  void initState() {
    super.initState();

    final fbUser = FirebaseAuth.instance.currentUser;
    _currentUserId = fbUser?.uid;
    _currentUserEmail = fbUser?.email;

    try {
      _usersStream = _chatService.getUsersStream();
    } catch (_) {
      // Firebase is not configured - handled as an error state below.
      _usersStream = null;
    }

    try {
      _unreadStream = _chatService.getUnreadSummariesStream();
    } catch (_) {
      // Firebase unavailable - badges simply stay hidden.
      _unreadStream = null;
    }
  }

  @override
  void dispose() {
    _searchChatController.dispose();
    super.dispose();
  }

  // "John Doe" when both names were stored, otherwise the username,
  // otherwise a neutral placeholder so partial profiles still render.
  String _displayName(Map<String, dynamic> user) {
    final fullName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
        .trim();

    if (fullName.isNotEmpty) return fullName;

    final username = (user['username'] ?? '').toString().trim();

    if (username.isNotEmpty) return username;

    final email = (user['email'] ?? '').toString().trim();

    if (email.isNotEmpty) return email;

    return 'Unknown user';
  }

  // Only an absolute http(s) url is safe to hand to NetworkImage. Empty
  // strings, whitespace, base64 blobs, file paths and other junk are
  // treated as "no image" so CircleAvatar never receives an unusable
  // provider.
  bool _usableImageUrl(String raw) {
    if (raw.isEmpty) return false;

    final uri = Uri.tryParse(raw);

    if (uri == null || !uri.hasAuthority) return false;

    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  // The uid stored on the document, falling back to the document id so
  // partial profiles still identify the right person.
  String _uidOf(Map<String, dynamic> user) {
    return (user['uid'] ?? user['docId'] ?? '').toString();
  }

  // Enhancement 1: the signed-in user is never listed in their own chat
  // list, so a self-chat cannot be started from here.
  // Enhancement 2: case-insensitive filter applied to the already
  // loaded list - no extra Firestore request per keystroke.
  // Enhancement 3: rows with unread messages float to the top, newest
  // activity first; every other user keeps the order Firestore returned,
  // so people who never chatted stay visible exactly where they were.
  List<Map<String, dynamic>> _visibleUsers(
    List<Map<String, dynamic>> allUsers,
    Map<String, UnreadSummary> unread,
  ) {
    final query = _searchText.trim().toLowerCase();

    final matching = <Map<String, dynamic>>[];

    for (final user in allUsers) {
      final uid = _uidOf(user);

      if (_currentUserId != null && uid == _currentUserId) {
        continue;
      }

      if (query.isNotEmpty) {
        final name = _displayName(user).toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final username = (user['username'] ?? '').toString().toLowerCase();

        final matches = name.contains(query) ||
            email.contains(query) ||
            username.contains(query);

        if (!matches) continue;
      }

      matching.add(user);
    }

    final withUnread = <MapEntry<int, Map<String, dynamic>>>[];
    final rest = <Map<String, dynamic>>[];

    for (var i = 0; i < matching.length; i++) {
      final user = matching[i];

      if (unread.containsKey(_uidOf(user))) {
        withUnread.add(MapEntry(i, user));
      } else {
        rest.add(user);
      }
    }

    // Newest unread activity first; the original index breaks ties so the
    // order stays deterministic.
    withUnread.sort((a, b) {
      final byDate =
          unread[_uidOf(b.value)]!.latestAt.compareTo(unread[_uidOf(a.value)]!.latestAt);

      return byDate != 0 ? byDate : a.key.compareTo(b.key);
    });

    return [...withUnread.map((entry) => entry.value), ...rest];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: Column(
        children: [
          SizedBox(height: 12.h),

          // Enhancement 2: search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextField(
              controller: _searchChatController,
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchChatController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.cancel),
                        onPressed: () {
                          setState(() {
                            _searchChatController.clear();
                            _searchText = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12.h,
                  horizontal: 12.w,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),

          SizedBox(height: 10.h),

          // Enhancement 1: registered users stream
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (_currentUserId == null) {
      return _emptyState('Sign in with your account to start chatting.');
    }

    final stream = _usersStream;

    if (stream == null) {
      return _emptyState('Chat is unavailable right now. Please try again.');
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (snapshot.hasError) {
          return _emptyState('Could not load users. Please try again.');
        }

        return StreamBuilder<Map<String, UnreadSummary>>(
          stream: _unreadStream,
          builder: (context, unreadSnapshot) {
            // A missing index or a transient listener error must never
            // take the user list down - the badges just stay hidden.
            if (unreadSnapshot.hasError && !_unreadErrorReported) {
              _unreadErrorReported = true;

              // The Firestore error names the collection-group index this
              // query needs (messages: receiverId + isRead); create it in
              // the console and restart to see badges again.
              debugPrint(
                'Chat unread stream unavailable: ${unreadSnapshot.error}',
              );
            }

            final unread = unreadSnapshot.hasError
                ? const <String, UnreadSummary>{}
                : unreadSnapshot.data ?? const <String, UnreadSummary>{};

            final users = _visibleUsers(snapshot.data ?? const [], unread);

            if (users.isEmpty) {
              final query = _searchText.trim();

              return _emptyState(
                query.isEmpty
                    ? 'No other users registered yet'
                    : 'No users match "$query"',
              );
            }

            return ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final name = _displayName(user);
                final email = (user['email'] ?? '').toString().trim();
                final image = (user['image'] ?? '').toString().trim();
                final showImage = _usableImageUrl(image) &&
                    !_brokenImageUrls.contains(image);
                final uid = _uidOf(user);
                final unreadCount = unread[uid]?.count ?? 0;

                return Card(
                  margin: EdgeInsets.only(bottom: 10.h),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 6.h,
                    ),
                    leading: CircleAvatar(
                      radius: 22.r,
                      backgroundColor: Colors.indigo.shade100,
                      // backgroundImage and onBackgroundImageError are gated
                      // by the same flag: CircleAvatar asserts the error
                      // listener may only be supplied together with an image,
                      // so an empty or unusable url can never trip that
                      // assertion.
                      backgroundImage: showImage ? NetworkImage(image) : null,
                      onBackgroundImageError: showImage
                          ? (_, __) {
                              // Broken url: fall back to the initials child
                              // instead of breaking the whole list.
                              if (!mounted) return;
                              setState(() => _brokenImageUrls.add(image));
                            }
                          : null,
                      child: showImage
                          ? null
                          : CustomText(
                              text: name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?',
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                    ),
                    title: CustomText(
                      text: name,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: CustomText(
                      text: email.isNotEmpty ? email : 'No email',
                      fontSize: 12.sp,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      color: Colors.grey.shade600,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unreadCount > 0)
                          Container(
                            constraints: BoxConstraints(
                              minWidth: 18.w,
                              maxWidth: 36.w,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: CustomText(
                              text:
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (unreadCount > 0) SizedBox(width: 6.w),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    onTap: () {
                      // Nothing to chat with when the uid is missing, and the
                      // current user is filtered out long before this point.
                      if (uid.isEmpty || uid == _currentUserId) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(
                            currentUserEmail: _currentUserEmail ?? '',
                            tappedUserId: uid,
                            tappedUserName: name,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: CustomText(
          text: message,
          fontSize: 16.sp,
          textAlign: TextAlign.center,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}
