import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naval_advmobprog/models/message.dart';

// Lab Activity 6 - MessageModel serialization checks.
void main() {
  group('MessageModel', () {
    test('toMap and fromMap keep every field', () {
      final timestamp = Timestamp.fromDate(DateTime(2026, 9, 27, 14, 30));

      final message = MessageModel(
        senderId: 'uid_a',
        senderEmail: 'a@example.com',
        receiverId: 'uid_b',
        message: 'Hello!',
        timestamp: timestamp,
      );

      final restored = MessageModel.fromMap(message.toMap());

      expect(restored.senderId, 'uid_a');
      expect(restored.senderEmail, 'a@example.com');
      expect(restored.receiverId, 'uid_b');
      expect(restored.message, 'Hello!');
      expect(restored.timestamp, timestamp);
    });

    test('fromMap falls back safely when fields are missing', () {
      final restored = MessageModel.fromMap(const {});

      expect(restored.senderId, '');
      expect(restored.senderEmail, '');
      expect(restored.receiverId, '');
      expect(restored.message, '');
      expect(restored.timestamp, isA<Timestamp>());
    });

    test('fromMap converts DateTime and epoch milliseconds', () {
      final date = DateTime(2026, 1, 2, 3, 4, 5);

      expect(
        MessageModel.fromMap({'timestamp': Timestamp.fromDate(date)}).timestamp,
        Timestamp.fromDate(date),
      );

      expect(
        MessageModel.fromMap({'timestamp': date}).timestamp,
        Timestamp.fromDate(date),
      );

      expect(
        MessageModel.fromMap({
          'timestamp': date.millisecondsSinceEpoch,
        }).timestamp,
        Timestamp.fromDate(date),
      );
    });

    test('fromMap tolerates a null timestamp', () {
      final restored = MessageModel.fromMap({
        'senderId': 'uid_a',
        'message': 'pending write',
        'timestamp': null,
      });

      expect(restored.message, 'pending write');
      expect(restored.timestamp, isA<Timestamp>());
    });
  });
}
