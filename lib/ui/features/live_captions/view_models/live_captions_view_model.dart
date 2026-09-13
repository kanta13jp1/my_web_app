import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/live_caption_translation_gateway.dart';
import '../domain/live_caption_models.dart';
import '../services/live_speech_recognizer.dart';

class LiveCaptionsViewModel extends ChangeNotifier {
  LiveCaptionsViewModel({
    required LiveCaptionTranslationGateway translationGateway,
    required LiveSpeechRecognizer speechRecognizer,
    DateTime Function()? now,
    int maxSegments = 30,
  })  : _translationGateway = translationGateway,
        _speechRecognizer = speechRecognizer,
        _now = now ?? DateTime.now,
        _maxSegments = maxSegments,
        _status = speechRecognizer.isSupported
            ? LiveCaptionStatus.idle
            : LiveCaptionStatus.unsupported;

  final LiveCaptionTranslationGateway _translationGateway;
  final LiveSpeechRecognizer _speechRecognizer;
  final DateTime Function() _now;
  final int _maxSegments;

  LiveCaptionStatus _status;
  String _sourceLanguageTag = 'ja-JP';
  final Set<String> _targetLanguageTags = <String>{'en-US'};
  String _viewerLanguageTag = 'en-US';
  final List<LiveCaptionSegment> _segments = <LiveCaptionSegment>[];
  String _interimText = '';
  String? _errorMessage;
  Duration? _lastTranslationLatency;
  bool _isListening = false;
  bool _isStarting = false;
  bool _disposed = false;
  int _pendingTranslations = 0;
  int _nextSegmentId = 1;
  int _recognitionSession = 0;

  LiveCaptionStatus get status => _status;
  LiveCaptionLanguage get sourceLanguage =>
      liveCaptionLanguageByTag(_sourceLanguageTag);
  String get sourceLanguageTag => _sourceLanguageTag;
  Set<String> get targetLanguageTags =>
      Set<String>.unmodifiable(_targetLanguageTags);
  String get viewerLanguageTag => _viewerLanguageTag;
  List<LiveCaptionSegment> get segments =>
      List<LiveCaptionSegment>.unmodifiable(_segments);
  String get interimText => _interimText;
  String? get errorMessage => _errorMessage;
  Duration? get lastTranslationLatency => _lastTranslationLatency;
  bool get isListening => _isListening;
  bool get isSupported => _speechRecognizer.isSupported;

  String get statusLabel {
    switch (_status) {
      case LiveCaptionStatus.idle:
        return '待機中';
      case LiveCaptionStatus.listening:
        return '音声認識中';
      case LiveCaptionStatus.translating:
        return '翻訳中';
      case LiveCaptionStatus.stopped:
        return '停止中';
      case LiveCaptionStatus.unsupported:
        return '非対応ブラウザー';
      case LiveCaptionStatus.error:
        return 'エラー';
    }
  }

  String get currentViewerText {
    if (_viewerLanguageTag == _sourceLanguageTag && _interimText.isNotEmpty) {
      return _interimText;
    }
    if (_segments.isEmpty) {
      return _interimText.isEmpty ? '字幕はここに表示されます' : _interimText;
    }
    return _segments.last.textFor(_viewerLanguageTag);
  }

  void setSourceLanguage(String languageTag) {
    if (_isListening || languageTag == _sourceLanguageTag) return;
    _sourceLanguageTag = languageTag;
    _targetLanguageTags.remove(languageTag);
    if (_targetLanguageTags.isEmpty) {
      _targetLanguageTags.add(
        kLiveCaptionLanguages
            .firstWhere((language) => language.tag != languageTag)
            .tag,
      );
    }
    if (_viewerLanguageTag == languageTag ||
        !_targetLanguageTags.contains(_viewerLanguageTag)) {
      _viewerLanguageTag = _targetLanguageTags.first;
    }
    _notify();
  }

  void toggleTargetLanguage(String languageTag) {
    if (languageTag == _sourceLanguageTag) return;
    if (_targetLanguageTags.contains(languageTag)) {
      if (_targetLanguageTags.length == 1) return;
      _targetLanguageTags.remove(languageTag);
      if (_viewerLanguageTag == languageTag) {
        _viewerLanguageTag = _targetLanguageTags.first;
      }
    } else {
      _targetLanguageTags.add(languageTag);
      unawaited(_backfillTargetLanguage(languageTag));
    }
    _notify();
  }

  void setViewerLanguage(String languageTag) {
    final isAvailable = languageTag == _sourceLanguageTag ||
        _targetLanguageTags.contains(languageTag);
    if (!isAvailable || languageTag == _viewerLanguageTag) return;
    _viewerLanguageTag = languageTag;
    _notify();
  }

  Future<bool> start() async {
    if (_isListening || _isStarting) return true;
    if (!_speechRecognizer.isSupported) {
      _status = LiveCaptionStatus.unsupported;
      _errorMessage = 'ChromeまたはEdgeの最新版でマイクを許可してください。';
      _notify();
      return false;
    }

    _errorMessage = null;
    _isStarting = true;
    _isListening = true;
    final session = ++_recognitionSession;
    _status = _pendingTranslations > 0
        ? LiveCaptionStatus.translating
        : LiveCaptionStatus.listening;
    _notify();
    try {
      await _speechRecognizer.start(
        languageTag: _sourceLanguageTag,
        onResult: ({required transcript, required isFinal}) {
          if (_disposed || session != _recognitionSession || !_isListening) {
            return;
          }
          unawaited(ingestTranscript(transcript, isFinal: isFinal));
        },
        onError: (message) => _handleSpeechError(session, message),
      );
      if (_disposed || session != _recognitionSession || !_isListening) {
        return false;
      }
      _isStarting = false;
      _status = _pendingTranslations > 0
          ? LiveCaptionStatus.translating
          : LiveCaptionStatus.listening;
      _notify();
      return true;
    } catch (error) {
      if (_disposed || session != _recognitionSession) return false;
      _isStarting = false;
      _isListening = false;
      _status = LiveCaptionStatus.error;
      _errorMessage = error.toString();
      _notify();
      return false;
    }
  }

  Future<void> stop() async {
    ++_recognitionSession;
    _isStarting = false;
    _isListening = false;
    _interimText = '';
    _status = _pendingTranslations > 0
        ? LiveCaptionStatus.translating
        : LiveCaptionStatus.stopped;
    _notify();
    await _speechRecognizer.stop();
  }

  Future<void> ingestTranscript(
    String transcript, {
    required bool isFinal,
  }) async {
    final normalized = transcript.trim();
    if (normalized.isEmpty) return;

    if (!isFinal) {
      _interimText = normalized;
      _notify();
      return;
    }

    _interimText = '';
    final segment = LiveCaptionSegment(
      id: _nextSegmentId++,
      sourceLanguageTag: _sourceLanguageTag,
      sourceText: normalized,
      receivedAt: _now(),
    );
    _segments.add(segment);
    if (_segments.length > _maxSegments) {
      _segments.removeRange(0, _segments.length - _maxSegments);
    }

    final targets = _targetLanguageTags
        .map(liveCaptionLanguageByTag)
        .toList(growable: false);
    _pendingTranslations += targets.length;
    _status = targets.isEmpty
        ? (_isListening
            ? LiveCaptionStatus.listening
            : LiveCaptionStatus.stopped)
        : LiveCaptionStatus.translating;
    _notify();

    await Future.wait<void>(
      targets.map(
        (target) => _translateSegment(
          segmentId: segment.id,
          text: normalized,
          source: sourceLanguage,
          target: target,
        ),
      ),
    );
    _pendingTranslations -= targets.length;
    if (_disposed) return;
    _lastTranslationLatency = _now().difference(segment.receivedAt);
    if (_status != LiveCaptionStatus.error) {
      _status = _pendingTranslations > 0
          ? LiveCaptionStatus.translating
          : (_isListening
              ? LiveCaptionStatus.listening
              : LiveCaptionStatus.stopped);
    }
    _notify();
  }

  void clearSegments() {
    _segments.clear();
    _interimText = '';
    _lastTranslationLatency = null;
    _notify();
  }

  Future<void> _translateSegment({
    required int segmentId,
    required String text,
    required LiveCaptionLanguage source,
    required LiveCaptionLanguage target,
  }) async {
    try {
      final translated = await _translationGateway.translate(
        text: text,
        sourceLanguage: source,
        targetLanguage: target,
      );
      if (_disposed) return;
      final index = _segments.indexWhere((item) => item.id == segmentId);
      if (index < 0) return;
      _segments[index] = _segments[index].withTranslation(
        target.tag,
        translated,
      );
      _notify();
    } catch (error) {
      if (_disposed) return;
      if (_status != LiveCaptionStatus.error) {
        _errorMessage = '${target.label}字幕を生成できませんでした: $error';
      }
      _notify();
    }
  }

  Future<void> _backfillTargetLanguage(String languageTag) async {
    final target = liveCaptionLanguageByTag(languageTag);
    final missingSegments = _segments
        .where((segment) => !segment.hasTranslation(languageTag))
        .toList(growable: false);
    if (missingSegments.isEmpty || _disposed) return;

    _pendingTranslations += missingSegments.length;
    if (_status != LiveCaptionStatus.error) {
      _status = LiveCaptionStatus.translating;
    }
    _notify();

    await Future.wait<void>(
      missingSegments.map(
        (segment) => _translateSegment(
          segmentId: segment.id,
          text: segment.sourceText,
          source: liveCaptionLanguageByTag(segment.sourceLanguageTag),
          target: target,
        ),
      ),
    );
    _pendingTranslations -= missingSegments.length;
    if (_disposed) return;
    if (_status != LiveCaptionStatus.error) {
      _status = _pendingTranslations > 0
          ? LiveCaptionStatus.translating
          : (_isListening
              ? LiveCaptionStatus.listening
              : LiveCaptionStatus.stopped);
    }
    _notify();
  }

  void _handleSpeechError(int session, String message) {
    if (_disposed || session != _recognitionSession) return;
    ++_recognitionSession;
    _isStarting = false;
    _isListening = false;
    _interimText = '';
    _status = LiveCaptionStatus.error;
    _errorMessage = message;
    _notify();
    unawaited(_speechRecognizer.stop());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    ++_recognitionSession;
    _isStarting = false;
    _isListening = false;
    _disposed = true;
    _speechRecognizer.dispose();
    super.dispose();
  }
}
