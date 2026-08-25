import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/live_captions/data/live_caption_translation_gateway.dart';
import 'package:my_web_app/ui/features/live_captions/domain/live_caption_models.dart';
import 'package:my_web_app/ui/features/live_captions/live_captions_feature.dart';
import 'package:my_web_app/ui/features/live_captions/services/live_speech_recognizer.dart';

void main() {
  testWidgets('starts recognition and renders translated captions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final recognizer = _FakeSpeechRecognizer();

    await tester.pumpWidget(
      MaterialApp(
        home: LiveCaptionsFeature(
          translationGateway: _FakeTranslationGateway(),
          speechRecognizer: recognizer,
        ),
      ),
    );

    expect(find.byKey(const Key('live-captions-wide')), findsOneWidget);
    expect(find.byKey(const Key('live-caption-preview')), findsOneWidget);
    expect(find.byKey(const Key('live-caption-start')), findsOneWidget);

    await tester.tap(find.byKey(const Key('live-caption-start')));
    await tester.pump();
    expect(find.byKey(const Key('live-caption-stop')), findsOneWidget);

    recognizer.emit('みなさん、こんにちは', isFinal: true);
    await tester.pumpAndSettle();

    expect(find.text('Hello, everyone.'), findsWidgets);
    final overlaySemantics = tester.widgetList<Semantics>(
      find.ancestor(
        of: find.byKey(const Key('live-caption-overlay')),
        matching: find.byType(Semantics),
      ),
    );
    expect(
      overlaySemantics.any((widget) => widget.properties.liveRegion == true),
      isTrue,
    );

    final koreanChip = find.byKey(const Key('live-caption-target-ko-KR'));
    expect(tester.widget<FilterChip>(koreanChip).selected, isFalse);
    await tester.tap(koreanChip);
    await tester.pump();
    expect(tester.widget<FilterChip>(koreanChip).selected, isTrue);
  });

  testWidgets('uses the compact layout on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(640, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: LiveCaptionsFeature(
          translationGateway: _FakeTranslationGateway(),
          speechRecognizer: _FakeSpeechRecognizer(),
        ),
      ),
    );

    expect(find.byKey(const Key('live-captions-compact')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeTranslationGateway implements LiveCaptionTranslationGateway {
  @override
  Future<String> translate({
    required String text,
    required LiveCaptionLanguage sourceLanguage,
    required LiveCaptionLanguage targetLanguage,
  }) async {
    if (targetLanguage.tag == 'en-US') return 'Hello, everyone.';
    return '$text (${targetLanguage.label})';
  }
}

class _FakeSpeechRecognizer implements LiveSpeechRecognizer {
  LiveSpeechResultCallback? _onResult;

  @override
  bool get isSupported => true;

  @override
  Future<void> start({
    required String languageTag,
    required LiveSpeechResultCallback onResult,
    required LiveSpeechErrorCallback onError,
  }) async {
    _onResult = onResult;
  }

  void emit(String text, {required bool isFinal}) =>
      _onResult?.call(text, isFinal);

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
