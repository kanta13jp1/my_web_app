import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/board_meeting.dart';

void main() {
  group('BoardMeetingLog', () {
    test('constructor initializes properties correctly', () {
      final now = DateTime.now();
      final message = BoardMessage(
        id: 'msg1',
        speakerName: 'John Doe',
        role: 'Developer',
        content: 'This is a test message.',
        timestamp: now,
      );
      final log = BoardMeetingLog(
        id: 'log1',
        userId: 'user1',
        topic: 'Test Topic',
        conclusion: 'Test Conclusion',
        messages: [message],
        createdAt: now,
      );

      expect(log.id, 'log1');
      expect(log.userId, 'user1');
      expect(log.topic, 'Test Topic');
      expect(log.conclusion, 'Test Conclusion');
      expect(log.messages, [message]);
      expect(log.createdAt, now);
    });
  });

  group('BoardMessage', () {
    test('constructor initializes properties correctly', () {
      final now = DateTime.now();
      final message = BoardMessage(
        id: 'msg1',
        speakerName: 'John Doe',
        role: 'Developer',
        content: 'This is a test message.',
        timestamp: now,
      );

      expect(message.id, 'msg1');
      expect(message.speakerName, 'John Doe');
      expect(message.role, 'Developer');
      expect(message.content, 'This is a test message.');
      expect(message.timestamp, now);
    });

    test('empty() returns a BoardMessage with default values', () {
      final message = BoardMessage.empty();

      expect(message.id, '');
      expect(message.speakerName, '');
      expect(message.role, '');
      expect(message.content, '');
      expect(message.timestamp, DateTime(0));
    });
  });
}
