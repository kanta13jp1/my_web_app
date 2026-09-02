import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/cartesia_voice_session_service.dart';

void main() {
  group('CartesiaVoiceSessionService', () {
    test('requests a scoped session and parses the runtime contract', () async {
      String? action;
      Map<String, dynamic>? body;
      final service = CartesiaVoiceSessionService(
        invoker: (requestedAction, requestedBody) async {
          action = requestedAction;
          body = requestedBody;
          return <String, dynamic>{
            'success': true,
            'available': true,
            'access_token': 'short-lived-token',
            'websocket_url': 'wss://api.cartesia.ai/tts/websocket',
            'api_version': '2026-03-01',
            'model_id': 'sonic-3-2026-01-12',
            'voice_id': 'voice-id',
            'max_session_seconds': 300,
          };
        },
      );

      final config = await service.createSession();

      expect(action, 'voice.cartesia_session.start');
      expect(body, isEmpty);
      expect(config.isUsable, isTrue);
      expect(config.modelId, 'sonic-3-2026-01-12');
      expect(config.maxSessionSeconds, 300);
    });

    test('surfaces provider configuration failures without a client key', () {
      final service = CartesiaVoiceSessionService(
        invoker: (_, __) async => <String, dynamic>{
          'success': false,
          'available': false,
          'reason': 'CARTESIA_API_KEY not configured',
        },
      );

      expect(
        service.createSession,
        throwsA(
          isA<CartesiaVoiceUnavailable>().having(
            (error) => error.reason,
            'reason',
            contains('CARTESIA_API_KEY'),
          ),
        ),
      );
    });

    test('syncs the bounded call transcript into the support ticket action',
        () async {
      String? action;
      Map<String, dynamic>? body;
      final service = CartesiaVoiceSessionService(
        invoker: (requestedAction, requestedBody) async {
          action = requestedAction;
          body = requestedBody;
          return <String, dynamic>{
            'success': true,
            'ticket_id': 'ticket-42',
          };
        },
      );

      final ticketId = await service.finishSession(
        sessionId: 'session-1',
        duration: const Duration(seconds: 42),
        assistantCharacterCount: 18,
        transcript: <CartesiaVoiceTranscriptEntry>[
          CartesiaVoiceTranscriptEntry(
            role: 'user',
            text: '設定方法を教えてください',
            recordedAt: DateTime.utc(2026, 8, 7, 1),
          ),
          CartesiaVoiceTranscriptEntry(
            role: 'assistant',
            text: '設定画面を開いてください。',
            recordedAt: DateTime.utc(2026, 8, 7, 1, 0, 1),
          ),
        ],
      );

      expect(action, 'voice.cartesia_session.finish');
      expect(ticketId, 'ticket-42');
      expect(body?['session_id'], 'session-1');
      expect(body?['duration_seconds'], 42);
      expect(body?['assistant_character_count'], 18);
      expect(body?['transcript'], hasLength(2));
    });

    test('does not create an empty support ticket', () async {
      var called = false;
      final service = CartesiaVoiceSessionService(
        invoker: (_, __) async {
          called = true;
          return <String, dynamic>{};
        },
      );

      final ticketId = await service.finishSession(
        sessionId: 'session-1',
        duration: Duration.zero,
        assistantCharacterCount: 0,
        transcript: const <CartesiaVoiceTranscriptEntry>[],
      );

      expect(ticketId, isNull);
      expect(called, isFalse);
    });
  });

  group('CartesiaVoiceStyle', () {
    test('uses a sympathetic slower delivery for an apology', () {
      final style = CartesiaVoiceStyle.infer('ご不便をおかけして申し訳ありません。');

      expect(style.emotion, 'sympathetic');
      expect(style.speed, 0.9);
    });

    test('uses curiosity and translates laughter into a Sonic tag', () {
      final style = CartesiaVoiceStyle.infer('こちらでよいですか？（笑）');

      expect(style.emotion, 'curious');
      expect(style.addLaughter, isTrue);
      expect(
        style.prepareTranscript('こちらでよいですか？（笑）'),
        'こちらでよいですか？[laughter]',
      );
    });
  });
}
