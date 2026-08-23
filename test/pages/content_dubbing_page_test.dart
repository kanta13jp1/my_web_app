import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/content_dubbing_page.dart';
import 'package:my_web_app/services/voice_dubbing_service.dart';

class _FakeVoiceDubbingApi implements VoiceDubbingApi {
  VoiceDubbingRequest? request;
  int previewCalls = 0;

  static const voice = VoiceOption(
    id: 'voice-123456',
    name: 'Aiko',
    category: 'premade',
    description: 'Japanese narration',
    previewUrl: 'https://example.test/preview.mp3',
    publicOwnerId:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    labels: {'language': 'ja', 'gender': 'female'},
  );

  static const usage = VoiceUsage(
    tier: 'free',
    used: 100,
    limit: 5000,
    remaining: 4900,
  );

  @override
  Future<VoiceCatalogPage> loadVoices({
    String search = '',
    String? pageToken,
  }) async {
    return const VoiceCatalogPage(
      voices: [voice],
      hasMore: true,
      nextPageToken: 'page-2',
      totalCount: 240,
    );
  }

  @override
  Future<VoiceUsage> loadUsage() async => usage;

  @override
  Future<VoiceDubbingResult> generate(VoiceDubbingRequest request) async {
    this.request = request;
    return const VoiceDubbingResult(
      audioUrl: 'https://example.test/audio.mp3',
      storagePath: 'user/2026-08/audio.mp3',
      fileName: 'multilingual-dubbing.mp3',
      characterCount: 5,
      chunkCount: 1,
      expiresAt: null,
      usage: VoiceUsage(tier: 'free', used: 105, limit: 5000, remaining: 4895),
    );
  }

  @override
  Future<void> preview(VoiceDubbingResult result) async {
    previewCalls += 1;
  }

  @override
  Future<void> previewVoice(VoiceOption voice) async {}

  @override
  Future<void> download(VoiceDubbingResult result) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('generates a downloadable multilingual audio result', (
    tester,
  ) async {
    final api = _FakeVoiceDubbingApi();
    await tester.pumpWidget(MaterialApp(home: ContentDubbingPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('多言語ダビング'), findsOneWidget);
    expect(find.textContaining('240'), findsOneWidget);
    expect(find.text('FREE  100 / 5,000文字'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('dubbing-text')), 'こんにちは');
    final generate = find.byKey(const Key('generate-dubbing'));
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();

    expect(api.request?.text, 'こんにちは');
    expect(api.request?.language.code, 'ja');
    expect(api.request?.voice.id, _FakeVoiceDubbingApi.voice.id);
    expect(api.previewCalls, 1);
    expect(find.text('multilingual-dubbing.mp3'), findsOneWidget);
    expect(find.byTooltip('ダウンロード'), findsOneWidget);
  });

  testWidgets('keeps the dubbing controls usable at a mobile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: ContentDubbingPage(api: _FakeVoiceDubbingApi())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dubbing-language')), findsOneWidget);
    expect(find.byKey(const Key('dubbing-voice')), findsOneWidget);
    expect(find.byKey(const Key('generate-dubbing')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
