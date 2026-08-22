import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_comments_service.dart';

void main() {
  group('isExpectedNoteCommentRealtimeDisconnect', () {
    test('accepts a normal websocket close', () {
      const error = 'RealtimeSubscribeException(status: '
          'RealtimeSubscribeStatus.channelError, details: '
          'RealtimeCloseEvent(code: 1000, reason: ))';

      expect(isExpectedNoteCommentRealtimeDisconnect(error), isTrue);
    });

    test('accepts a channel close without details', () {
      const error = 'RealtimeSubscribeException(status: '
          'RealtimeSubscribeStatus.channelError, details: null)';

      expect(isExpectedNoteCommentRealtimeDisconnect(error), isTrue);
    });

    test('keeps unexpected realtime failures visible', () {
      const error = 'RealtimeSubscribeException(status: '
          'RealtimeSubscribeStatus.timedOut, details: timeout)';

      expect(isExpectedNoteCommentRealtimeDisconnect(error), isFalse);
    });
  });
}
