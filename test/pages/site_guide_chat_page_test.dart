import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/site_guide_catalog_item.dart';
import 'package:my_web_app/pages/site_guide_chat_page.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/cartesia_voice_client.dart';
import 'package:my_web_app/services/cartesia_voice_session_service.dart';
import 'package:my_web_app/services/site_guide_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSiteGuideChatService extends SiteGuideChatService {
  _FakeSiteGuideChatService(this._answer);

  final SiteGuideChatAnswer _answer;
  String? lastQuestion;
  String? lastSessionId;

  @override
  Future<SiteGuideChatAnswer> answerQuestion(
    String question, {
    String? sessionId,
  }) async {
    lastQuestion = question;
    lastSessionId = sessionId;
    return _answer;
  }
}

class _FakeCartesiaVoiceSessionService extends CartesiaVoiceSessionService {
  _FakeCartesiaVoiceSessionService()
      : super(invoker: (_, __) async => <String, dynamic>{});

  int finishCalls = 0;
  List<CartesiaVoiceTranscriptEntry> savedTranscript =
      <CartesiaVoiceTranscriptEntry>[];

  @override
  Future<CartesiaVoiceSessionConfig> createSession() async {
    return const CartesiaVoiceSessionConfig(
      accessToken: 'token',
      websocketUrl: 'wss://api.cartesia.ai/tts/websocket',
      apiVersion: '2026-03-01',
      modelId: 'sonic-3-2026-01-12',
      voiceId: 'voice-id',
      maxSessionSeconds: 300,
    );
  }

  @override
  Future<String?> finishSession({
    required String sessionId,
    required Duration duration,
    required int assistantCharacterCount,
    required List<CartesiaVoiceTranscriptEntry> transcript,
  }) async {
    finishCalls += 1;
    savedTranscript = List<CartesiaVoiceTranscriptEntry>.from(transcript);
    return 'ticket-1';
  }
}

class _FakeCartesiaVoiceClient implements CartesiaVoiceClient {
  CartesiaTranscriptCallback? onTranscript;
  CartesiaStatusCallback? onStatus;
  int startCalls = 0;
  int stopCalls = 0;
  final List<(String, CartesiaVoiceStyle)> spoken =
      <(String, CartesiaVoiceStyle)>[];

  @override
  bool get isSupported => true;

  @override
  Future<void> start({
    required CartesiaVoiceSessionConfig config,
    required CartesiaTranscriptCallback onTranscript,
    required CartesiaStatusCallback onStatus,
    required CartesiaErrorCallback onError,
  }) async {
    startCalls += 1;
    this.onTranscript = onTranscript;
    this.onStatus = onStatus;
    onStatus('listening');
  }

  @override
  Future<void> speak(String text, CartesiaVoiceStyle style) async {
    spoken.add((text, style));
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('SiteGuideChatPage sends questions and shows observability', (
    tester,
  ) async {
    var openedTool = false;
    var openedManual = false;
    final service = _FakeSiteGuideChatService(
      SiteGuideChatAnswer(
        text: '資産管理を開くと、お金まわりを一か所で見られます。',
        source: 'test-source',
        answeredAt: DateTime(2026, 4, 23, 22, 30),
        observability: const AiHubChatObservability(
          provider: 'deepinfra',
          latencyMs: 150,
          traceId: 'trace-12345678',
          sessionId: 'session-87654321',
        ),
        suggestions: const <SiteGuideToolSuggestion>[
          SiteGuideToolSuggestion(
            id: 'asset-management',
            title: '資産管理',
            subtitle: 'お金の入口',
            sectionId: 'office',
            sectionTitle: 'Office',
            score: 12,
          ),
        ],
      ),
    );

    final toolCatalog = <SiteGuideActionEntry>[
      SiteGuideActionEntry(
        item: const SiteGuideCatalogItem(
          id: 'asset-management',
          sectionId: 'office',
          sectionTitle: 'Office',
          title: '資産管理',
          subtitle: 'お金の入口',
          keywords: <String>['資産管理'],
        ),
        onOpen: (_) async {
          openedTool = true;
        },
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SiteGuideChatPage(
          service: service,
          toolCatalog: toolCatalog,
          onOpenUserManual: () {
            openedManual = true;
          },
          isAuthenticated: () => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '資産管理はどこですか');
    await tester.tap(find.byKey(const Key('site_guide_send')));
    await tester.pumpAndSettle();

    expect(service.lastQuestion, '資産管理はどこですか');
    expect(service.lastSessionId, isNotNull);
    expect(find.text('資産管理を開くと、お金まわりを一か所で見られます。'), findsOneWidget);
    expect(find.text('AI observability'), findsOneWidget);
    expect(find.textContaining('trace '), findsOneWidget);
    expect(
      find.byKey(const Key('site_guide_open_asset-management')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('site_guide_open_asset-management')));
    await tester.pumpAndSettle();
    expect(openedTool, isTrue);

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
    expect(openedManual, isTrue);
  });

  testWidgets('SiteGuideChatPage sends the initial question automatically', (
    tester,
  ) async {
    final service = _FakeSiteGuideChatService(
      SiteGuideChatAnswer(
        text: 'まずは今日の一手から始めましょう。',
        source: 'test-source',
        answeredAt: DateTime(2026, 4, 23, 22, 31),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SiteGuideChatPage(
          initialQuestion: 'まずは何を使えばよいですか',
          service: service,
          toolCatalog: const <SiteGuideActionEntry>[],
          isAuthenticated: () => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.lastQuestion, 'まずは何を使えばよいですか');
    expect(find.text('まずは今日の一手から始めましょう。'), findsOneWidget);
  });

  testWidgets('voice call streams a reply and saves a support transcript', (
    tester,
  ) async {
    final chatService = _FakeSiteGuideChatService(
      SiteGuideChatAnswer(
        text: 'ご不便をおかけして申し訳ありません。設定画面をご案内します。',
        source: 'test-source',
        answeredAt: DateTime(2026, 8, 7),
      ),
    );
    final voiceSessionService = _FakeCartesiaVoiceSessionService();
    final voiceClient = _FakeCartesiaVoiceClient();

    await tester.pumpWidget(
      MaterialApp(
        home: SiteGuideChatPage(
          service: chatService,
          toolCatalog: const <SiteGuideActionEntry>[],
          voiceSessionService: voiceSessionService,
          voiceClient: voiceClient,
          isAuthenticated: () => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('site_guide_voice_toggle')));
    await tester.pumpAndSettle();

    expect(voiceClient.startCalls, 1);
    expect(find.text('音声通話を終了'), findsOneWidget);

    voiceClient.onTranscript?.call('ログイン設定を教えてください');
    await tester.pumpAndSettle();

    expect(chatService.lastQuestion, 'ログイン設定を教えてください');
    expect(voiceClient.spoken, hasLength(1));
    expect(voiceClient.spoken.single.$2.emotion, 'sympathetic');

    await tester.tap(find.byKey(const Key('site_guide_voice_toggle')));
    await tester.pumpAndSettle();

    expect(voiceClient.stopCalls, greaterThanOrEqualTo(1));
    expect(voiceSessionService.finishCalls, 1);
    expect(
      voiceSessionService.savedTranscript.map((entry) => entry.role),
      <String>['user', 'assistant'],
    );
    expect(find.byKey(const Key('site_guide_voice_saved')), findsOneWidget);
  });
}
