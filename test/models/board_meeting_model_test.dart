import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/board_meeting_model.dart';

void main() {
  group('BoardMeetingModel Tests', () {
    test('BoardMessage.fromMap parses correctly', () {
      final map = {
        'id': 'msg-1',
        'speaker_name': 'Steve',
        'role': 'CEO',
        'content': 'Hello',
        'created_at': '2025-01-01T12:00:00Z',
      };

      final message = BoardMessage.fromMap(map);

      expect(message.id, 'msg-1');
      expect(message.speakerName, 'Steve');
      expect(message.role, 'CEO');
      expect(message.content, 'Hello');
      expect(message.timestamp, isNotNull);
    });

    test('BoardMeetingLog.fromMap parses list of messages', () {
      final map = {
        'id': 'meet-1',
        'topic': 'Strategy',
        'conclusion': 'Approved',
        'created_at': '2025-01-01T10:00:00Z',
        'messages': [
          {
            'id': 'm1',
            'speaker_name': 'A',
            'role': 'r',
            'content': 'c',
            'created_at': '2025-01-01T10:00:00Z',
          }
        ],
      };

      final log = BoardMeetingLog.fromMap(map);

      expect(log.id, 'meet-1');
      expect(log.topic, 'Strategy');
      expect(log.messages.length, 1);
      expect(log.messages.first.id, 'm1');
    });
  });
}
