import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/chat_service.dart';
import '../widgets/custom_text.dart';

// A bubble shown while Firestore still confirms the write - this is the
// local "sending..." state from the lab sheet.
class _PendingMessage {
  final String id;
  final String text;

  _PendingMessage({required this.id, required this.text});
}

enum _MessageStatus { sending, sent }

class ChatDetailScreen extends StatefulWidget {
  final String currentUserEmail;
  final String tappedUserId;
  final String tappedUserName;

  const ChatDetailScreen({
    super.key,
    required this.currentUserEmail,
    required this.tappedUserId,
    required this.tappedUserName,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _msgCtrl = TextEditingController();
  final FocusNode _msgFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  final List<_PendingMessage> _pending = [];

  // Signed-in Firebase user (null when the session is gone).
  String? _currentUserId;

  // Created once in initState: rebuilding the screen (for example while
  // typing) must never open another Firestore listener.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;

  bool _isSending = false;

  // Keeps at most one "mark as read" commit in flight, no matter how
  // often the message snapshot asks for one.
  bool _markReadInFlight = false;

  // Safety net for the "chat with yourself" case. The chat list already
  // hides the current user, so this should never be reachable through
  // the normal UI flow.
  bool get _isSelfChat =>
      _currentUserId == null ||
      widget.tappedUserId.isEmpty ||
      widget.tappedUserId == _currentUserId;

  @override
  void initState() {
    super.initState();

    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final currentUserId = _currentUserId;

    if (currentUserId == null || widget.tappedUserId == currentUserId) {
      return;
    }

    try {
      _messagesStream = _chatService.getMessage(
        currentUserId,
        widget.tappedUserId,
      );
    } catch (_) {
      // Firebase unavailable - the error state below is shown instead.
      _messagesStream = null;
    }

    // Opening the conversation clears the chat list badge right away; the
    // snapshot below repeats the call if another message arrives while
    // this screen stays open.
    _markMessagesRead();
  }

  // Marks the messages this partner sent to me as read. My own outgoing
  // messages are never touched, and a failure is swallowed - the badge
  // simply stays until the next attempt.
  void _markMessagesRead() {
    final other = widget.tappedUserId;

    if (other.isEmpty || other == _currentUserId || _currentUserId == null) {
      return;
    }

    if (_markReadInFlight) return;

    _markReadInFlight = true;

    _chatService.markMessagesAsRead(other).catchError((_) {}).whenComplete(() {
      _markReadInFlight = false;
    });
  }

  // Schedules a mark-as-read pass after the current frame when the latest
  // snapshot still contains unread messages from the other user, so an
  // incoming message clears its badge without restarting the app.
  void _scheduleMarkRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final hasUnread = docs.any((doc) {
      final data = doc.data();

      return (data['senderId'] ?? '').toString() == widget.tappedUserId &&
          data['isRead'] == false;
    });

    if (!hasUnread) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markMessagesRead();
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _msgFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // The list runs in reverse, so offset 0 is the newest message.
  void _scrollToLatest() {
    if (!_scrollCtrl.hasClients) return;

    _scrollCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    // Rapid double taps cannot queue the same message twice.
    if (_isSending) return;

    final text = _msgCtrl.text.trim();

    // Empty and whitespace-only messages never leave the device.
    if (text.isEmpty) return;

    final currentUserId = _currentUserId;

    if (currentUserId == null || widget.tappedUserId == currentUserId) {
      return;
    }

    final pending = _PendingMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
    );

    setState(() {
      _isSending = true;
      _pending.insert(0, pending);
    });

    _msgCtrl.clear();
    _msgFocus.requestFocus();
    _scrollToLatest();

    try {
      await _chatService.sendMessage(widget.tappedUserId, text);

      if (!mounted) return;

      // The confirmed message replaces the optimistic bubble as soon as
      // the real-time snapshot arrives.
      setState(() {
        _pending.removeWhere((m) => m.id == pending.id);
      });
    } catch (_) {
      if (!mounted) return;

      // Roll back: drop the optimistic bubble and hand the text back so
      // a failed send never silently loses the message.
      final typed = _msgCtrl.text.trim();

      setState(() {
        _pending.removeWhere((m) => m.id == pending.id);
        _msgCtrl.text = typed.isEmpty ? text : '$text $typed';
        _msgCtrl.selection = TextSelection.collapsed(
          offset: _msgCtrl.text.length,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message could not be sent. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: CustomText(
          text: widget.tappedUserName,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _isSelfChat
          ? _buildUnavailable()
          : Column(
              children: [
                Expanded(child: _buildMessages()),
                _buildComposer(),
              ],
            ),
    );
  }

  // Self-chat and signed-out guards: no message list, no composer.
  Widget _buildUnavailable() {
    final signedOut = _currentUserId == null;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              signedOut
                  ? Icons.account_circle_outlined
                  : Icons.person_off_outlined,
              size: 56.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 12.h),
            CustomText(
              text: signedOut
                  ? 'Your session has ended. Please sign in again to chat.'
                  : 'You cannot start a chat with yourself.',
              fontSize: 15.sp,
              textAlign: TextAlign.center,
              color: Colors.grey.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    final stream = _messagesStream;

    if (stream == null) {
      return _statusMessage('Messages are unavailable right now.');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (snapshot.hasError) {
          return _statusMessage('Could not load messages. Please try again.');
        }

        final docs = snapshot.data?.docs ?? [];

        // Unread messages still sitting in this conversation (a new one
        // arrived while the chat is open) are marked read after the frame.
        _scheduleMarkRead(docs);

        if (docs.isEmpty && _pending.isEmpty) {
          return _statusMessage('Say hello \u{1F44B}');
        }

        return ListView.builder(
          controller: _scrollCtrl,
          reverse: true,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          // Pending bubbles sit at the bottom of the reversed list.
          itemCount: _pending.length + docs.length,
          itemBuilder: (context, index) {
            if (index < _pending.length) {
              final pending = _pending[index];

              return _AnimatedBubble(
                key: ValueKey('pending_${pending.id}'),
                isMe: true,
                child: _bubble(
                  text: pending.text,
                  isMe: true,
                  status: _MessageStatus.sending,
                ),
              );
            }

            final doc = docs[index - _pending.length];
            final data = doc.data();
            final isMe = (data['senderId'] ?? '').toString() == _currentUserId;
            final timestamp = data['timestamp'];

            return _AnimatedBubble(
              key: ValueKey(doc.id),
              isMe: isMe,
              child: _bubble(
                text: (data['message'] ?? '').toString(),
                isMe: isMe,
                status: isMe ? _MessageStatus.sent : null,
                timestamp: timestamp is Timestamp ? timestamp.toDate() : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                focusNode: _msgFocus,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(fontFamily: 'Poppins'),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Material(
              color: _isSending
                  ? Colors.grey.shade400
                  : Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isSending ? null : _send,
                child: Padding(
                  padding: EdgeInsets.all(10.r),
                  child: _isSending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusMessage(String text) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: CustomText(
          text: text,
          fontSize: 16.sp,
          textAlign: TextAlign.center,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _bubble({
    required String text,
    required bool isMe,
    _MessageStatus? status,
    DateTime? timestamp,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
                  colors: [Colors.indigo.shade600, Colors.indigo.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe ? null : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomText(
              text: text.isNotEmpty ? text : '[empty]',
              fontSize: 15.sp,
              color: isMe ? Colors.white : Colors.black87,
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timestamp != null)
                  CustomText(
                    text: _formatTime(timestamp),
                    fontSize: 10.sp,
                    color: isMe ? Colors.white70 : Colors.grey.shade600,
                  ),
                if (status != null) ...[
                  SizedBox(width: 4.w),
                  _statusIndicator(status, isMe),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // "sending..." while the write is in flight, a check mark once the
  // message has been stored by Firestore. Read state is tracked for the
  // chat list badge only, so no read receipt is drawn on the bubble.
  Widget _statusIndicator(_MessageStatus status, bool isMe) {
    final Color color = isMe ? Colors.white70 : Colors.grey.shade600;

    if (status == _MessageStatus.sending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10.sp,
            height: 10.sp,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          SizedBox(width: 4.w),
          CustomText(text: 'sending...', fontSize: 10.sp, color: color),
        ],
      );
    }

    return Icon(Icons.done, size: 14.sp, color: color);
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

// Fades and slides a bubble in the first time it appears. Keying by the
// Firestore document id (or the pending id) makes Flutter reuse the same
// element on later rebuilds, so the animation never replays and no
// message is ever duplicated.
class _AnimatedBubble extends StatelessWidget {
  final Widget child;
  final bool isMe;

  const _AnimatedBubble({super.key, required this.child, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((isMe ? 1 : -1) * (1 - value) * 24, 0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
