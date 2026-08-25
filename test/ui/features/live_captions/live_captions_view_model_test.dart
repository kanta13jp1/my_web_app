import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/live_captions/data/live_caption_translation_gateway.dart';
import 'package:my_web_app/ui/features/live_captions/domain/live_caption_models.dart';
import 'package:my_web_app/ui/features/live_captions/services/live_speech_recognizer.dart';
import 'package:my_web_app/ui/features/live_captions/view_models/live_captions_view_model.dart';

void main() {
  group('LiveCaptionsViewModel', () {
    late _FakeTranslationGateway translationGateway;
    late _FakeSpeechRecognizer speechRecognizer;
    late LiveCaptionsViewModel viewModel;

    setUp(() {
      translationGateway = _FakeTranslationGateway();
      speechRecognizer = _FakeSpeechRecognizer();
      viewModel = LiveCaptionsViewModel(
        translationGateway: translationGateway,
        speechRecognizer: speechRecognizer,
      );
    });

    tearDown(() => viewModel.dispose());

    test('uses Japanese speech and English viewer captions by default', () {
      expect(viewModel.sourceLanguageTag, 'ja-JP');
      expect(viewModel.targetLanguageTags, <String>{'en-US'});
      expect(viewModel.viewerLanguageTag, 'en-US');
      expect(viewModel.status, LiveCaptionStatus.idle);
    });

    test(
      'streams interim speech then stores translated final captions',
      () async {
        translationGateway.responses['en-US'] = 'Hello, everyone.';

        expect(await viewModel.start(), isTrue);
        expect(speechRecognizer.startedLanguageTag, 'ja-JP');
        expect(viewModel.status, LiveCaptionStatus.listening);

        speechRecognizer.emit('みなさん、こん', isFinal: false);
        await pumpEventQueue();
        expect(viewModel.interimText, 'みなさん、こん');

        speechRecognizer.emit('みなさん、こんにちは', isFinal: true);
        await pumpEventQueue();

        expect(viewModel.segments, hasLength(1));
        expect(viewModel.segments.single.sourceText, 'みなさん、こんにちは');
        expect(viewModel.segments.single.textFor('en-US'), 'Hello, everyone.');
        expect(viewModel.currentViewerText, 'Hello, everyone.');
        expect(viewModel.lastTranslationLatency, isNotNull);
        expect(viewModel.status, LiveCaptionStatus.listening);
      },
    );

    test('administrator can change source and enabled viewer languages', () {
      viewModel.setSourceLanguage('en-US');

      expect(viewModel.sourceLanguageTag, 'en-US');
      expect(viewModel.targetLanguageTags, contains('ja-JP'));
      expect(viewModel.targetLanguageTags, isNot(contains('en-US')));

      viewModel.toggleTargetLanguage('ko-KR');
      viewModel.setViewerLanguage('ko-KR');
      expect(viewModel.targetLanguageTags, contains('ko-KR'));
      expect(viewModel.viewerLanguageTag, 'ko-KR');

      viewModel.toggleTargetLanguage('ko-KR');
      expect(viewModel.targetLanguageTags, isNot(contains('ko-KR')));
      expect(viewModel.viewerLanguageTag, 'ja-JP');
    });

    test('keeps source text visible when one translation fails', () async {
      translationGateway.error = const LiveCaptionTranslationException(
        'temporary unavailable',
      );

      await viewModel.ingestTranscript('障害時も字幕を残す', isFinal: true);

      expect(viewModel.segments.single.textFor('en-US'), '障害時も字幕を残す');
      expect(viewModel.errorMessage, contains('英語字幕を生成できませんでした'));
    });

    test('coalesces repeated starts while recognition is starting', () async {
      speechRecognizer.startCompleter = Completer<void>();

      final firstStart = viewModel.start();
      final secondStart = viewModel.start();

      expect(speechRecognizer.startCalls, 1);
      expect(await secondStart, isTrue);
      speechRecognizer.startCompleter!.complete();
      expect(await firstStart, isTrue);
      expect(viewModel.status, LiveCaptionStatus.listening);
    });

    test('stops recognition and preserves error status on speech error',
        () async {
      await viewModel.start();

      speechRecognizer.emitError('マイク接続エラー');
      await pumpEventQueue();

      expect(speechRecognizer.stopCalls, 1);
      expect(viewModel.isListening, isFalse);
      expect(viewModel.status, LiveCaptionStatus.error);
      expect(viewModel.errorMessage, 'マイク接続エラー');
    });

    test('ignores speech callbacks from a stopped session', () async {
      await viewModel.start();
      await viewModel.stop();

      speechRecognizer.emit('停止後の字幕', isFinal: true);
      await pumpEventQueue();

      expect(viewModel.segments, isEmpty);
      expect(viewModel.status, LiveCaptionStatus.stopped);
    });

    test('translation completion does not overwrite a speech error', () async {
      translationGateway.completer = Completer<String>();
      await viewModel.start();

      speechRecognizer.emit('翻訳待機中', isFinal: true);
      await pumpEventQueue();
      speechRecognizer.emitError('音声認識エラー');
      await pumpEventQueue();
      translationGateway.completer!.complete('Translation completed');
      await pumpEventQueue();

      expect(viewModel.status, LiveCaptionStatus.error);
      expect(viewModel.errorMessage, '音声認識エラー');
    });

    test('backfills existing captions when a target language is added',
        () async {
      translationGateway.responses['en-US'] = 'Existing English caption';
      translationGateway.responses['ko-KR'] = '기존 한국어 자막';
      await viewModel.ingestTranscript('既存の字幕', isFinal: true);

      viewModel.toggleTargetLanguage('ko-KR');
      await pumpEventQueue();

      expect(viewModel.segments.single.textFor('ko-KR'), '기존 한국어 자막');
      expect(viewModel.status, LiveCaptionStatus.stopped);
    });

    test(
      'reports unsupported recognition without starting a session',
      () async {
        viewModel.dispose();
        speechRecognizer = _FakeSpeechRecognizer(supported: false);
        viewModel = LiveCaptionsViewModel(
          translationGateway: translationGateway,
          speechRecognizer: speechRecognizer,
        );

        expect(await viewModel.start(), isFalse);
        expect(viewModel.status, LiveCaptionStatus.unsupported);
        expect(viewModel.errorMessage, contains('Chrome'));
      },
    );
  });
}

class _FakeTranslationGateway implements LiveCaptionTranslationGateway {
  final Map<String, String> responses = <String, String>{};
  Exception? error;
  Completer<String>? completer;

  @override
  Future<String> translate({
    required String text,
    required LiveCaptionLanguage sourceLanguage,
    required LiveCaptionLanguage targetLanguage,
  }) async {
    if (error case final error?) throw error;
    if (completer case final completer?) return completer.future;
    return responses[targetLanguage.tag] ?? '$text (${targetLanguage.tag})';
  }
}

class _FakeSpeechRecognizer implements LiveSpeechRecognizer {
  _FakeSpeechRecognizer({this.supported = true});

  final bool supported;
  LiveSpeechResultCallback? _onResult;
  LiveSpeechErrorCallback? _onError;
  String? startedLanguageTag;
  Completer<void>? startCompleter;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<void> start({
    required String languageTag,
    required LiveSpeechResultCallback onResult,
    required LiveSpeechErrorCallback onError,
  }) async {
    startCalls++;
    startedLanguageTag = languageTag;
    _onResult = onResult;
    _onError = onError;
    await startCompleter?.future;
  }

  void emit(String text, {required bool isFinal}) =>
      _onResult?.call(transcript: text, isFinal: isFinal);

  void emitError(String message) => _onError?.call(message);

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  void dispose() {}
}
