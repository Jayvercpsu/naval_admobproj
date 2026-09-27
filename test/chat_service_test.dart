import 'package:flutter_test/flutter_test.dart';
import 'package:naval_advmobprog/services/chat_service.dart';

// Lab Activity 6 - deterministic chat room id checks: both users must
// always generate the exact same room for the same pair of uids.
void main() {
  group('ChatService.buildChatRoomId', () {
    const userA = 'abc123';
    const userB = 'xyz789';

    test('sorts the uids so the order never matters', () {
      expect(ChatService.buildChatRoomId(userA, userB), 'abc123_xyz789');
      expect(ChatService.buildChatRoomId(userB, userA), 'abc123_xyz789');
    });

    test('both users agree on one single room', () {
      final roomFromA = ChatService.buildChatRoomId(userA, userB);
      final roomFromB = ChatService.buildChatRoomId(userB, userA);

      expect(roomFromA, roomFromB);
      expect(roomFromA, contains(userA));
      expect(roomFromA, contains(userB));
    });

    test('different pairs never share a room', () {
      final firstPair = ChatService.buildChatRoomId(userA, userB);
      final otherPair = ChatService.buildChatRoomId(userA, 'other_uid');

      expect(firstPair, isNot(otherPair));
    });

    test('keeps the uids intact instead of scrambling them', () {
      final room = ChatService.buildChatRoomId(userA, userB);

      expect(room.split('_'), [userA, userB]);
    });
  });
}
