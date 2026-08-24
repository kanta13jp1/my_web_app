import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'cartesia_voice_client.dart';
import 'cartesia_voice_session_service.dart';

CartesiaVoiceClient createCartesiaVoiceClient() => WebCartesiaVoiceClient();

class WebCartesiaVoiceClient implements CartesiaVoiceClient {
  static const int _sampleRate = 44100;

  web.WebSocket? _socket;
  web.SpeechRecognition? _recognition;
  web.AudioContext? _audioContext;
  CartesiaVoiceSessionConfig? _config;
  CartesiaTranscriptCallback? _onTranscript;
  CartesiaStatusCallback? _onStatus;
  CartesiaErrorCallback? _onError;
  bool _active = false;
  bool _speaking = false;
  double _playAt = 0;
  Timer? _resumeTimer;

  @override
  bool get isSupported => true;

  @override
  Future<void> start({
    required CartesiaVoiceSessionConfig config,
    required CartesiaTranscriptCallback onTranscript,
    required CartesiaStatusCallback onStatus,
    required CartesiaErrorCallback onError,
  }) async {
    await stop();
    _config = config;
    _onTranscript = onTranscript;
    _onStatus = onStatus;
    _onError = onError;
    _active = true;

    final audioContext = web.AudioContext();
    _audioContext = audioContext;
    await audioContext.resume().toDart;
    _playAt = audioContext.currentTime;

    final uri = Uri.parse(config.websocketUrl).replace(
      queryParameters: <String, String>{
        ...Uri.parse(config.websocketUrl).queryParameters,
        'cartesia_version': config.apiVersion,
        'access_token': config.accessToken,
      },
    );
    final socket = web.WebSocket(uri.toString());
    _socket = socket;
    final connected = Completer<void>();

    socket.onopen = ((web.Event _) {
      _onStatus?.call('connected');
      if (!connected.isCompleted) connected.complete();
    }).toJS;
    socket.onerror = ((web.Event _) {
      const message = 'Cartesia WebSocket connection failed';
      _onError?.call(message);
      if (!connected.isCompleted) {
        connected.completeError(StateError(message));
      }
    }).toJS;
    socket.onclose = ((web.CloseEvent event) {
      if (_active && event.code != 1000) {
        _onError?.call('Cartesia connection closed (${event.code})');
      }
    }).toJS;
    socket.onmessage = ((web.MessageEvent event) {
      final raw = event.data;
      if (raw is! JSString) return;
      _handleSocketMessage(raw.toDart);
    }).toJS;

    await connected.future.timeout(const Duration(seconds: 8));
    _startRecognition();
  }

  void _startRecognition() {
    if (!_active || _speaking) return;
    try {
      final recognition = web.SpeechRecognition();
      recognition.lang = 'ja-JP';
      recognition.continuous = true;
      recognition.interimResults = false;
      recognition.maxAlternatives = 1;
      recognition.onresult = ((web.SpeechRecognitionEvent event) {
        final results = event.results;
        if (results.length == 0) return;
        final result = results.item(results.length - 1);
        if (!result.isFinal) return;
        final transcript = result.item(0).transcript.trim();
        if (transcript.isNotEmpty) {
          _speaking = true;
          _onStatus?.call('thinking');
          recognition.abort();
          _onTranscript?.call(transcript);
        }
      }).toJS;
      recognition.onerror = ((web.SpeechRecognitionErrorEvent event) {
        if (_active && event.error != 'aborted' && event.error != 'no-speech') {
          _onError?.call('Speech recognition failed: ${event.error}');
        }
      }).toJS;
      recognition.onend = (() {
        if (_active && !_speaking) {
          _resumeTimer?.cancel();
          _resumeTimer = Timer(
            const Duration(milliseconds: 250),
            _startRecognition,
          );
        }
      }).toJS;
      _recognition = recognition;
      recognition.start();
      _onStatus?.call('listening');
    } catch (error) {
      _onError?.call('Speech recognition is unavailable: $error');
    }
  }

  @override
  Future<void> speak(String text, CartesiaVoiceStyle style) async {
    final socket = _socket;
    final config = _config;
    if (!_active ||
        socket == null ||
        config == null ||
        socket.readyState != web.WebSocket.OPEN) {
      return;
    }
    _speaking = true;
    _resumeTimer?.cancel();
    _recognition?.abort();
    _onStatus?.call('speaking');
    final contextId = '${DateTime.now().microsecondsSinceEpoch}';
    try {
      socket.send(
        jsonEncode(<String, dynamic>{
          'model_id': config.modelId,
          'transcript': style.prepareTranscript(text),
          'voice': <String, String>{'mode': 'id', 'id': config.voiceId},
          'language': 'ja',
          'context_id': contextId,
          'output_format': const <String, dynamic>{
            'container': 'raw',
            'encoding': 'pcm_f32le',
            'sample_rate': _sampleRate,
          },
          'generation_config': <String, dynamic>{
            'speed': style.speed,
            'volume': 1,
            'emotion': style.emotion,
          },
          'continue': false,
        }).toJS,
      );
    } catch (error) {
      _speaking = false;
      _onError?.call('Cartesia generation request failed: $error');
      _startRecognition();
    }
  }

  void _handleSocketMessage(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return;
      final type = data['type']?.toString();
      if (type == 'chunk') {
        final encoded = data['data']?.toString() ?? '';
        if (encoded.isNotEmpty) _queuePcmChunk(base64Decode(encoded));
        return;
      }
      if (type == 'done') {
        _resumeAfterPlayback();
        return;
      }
      if (type == 'error') {
        _speaking = false;
        _onError?.call(
          data['message']?.toString() ?? 'Cartesia generation failed',
        );
        _startRecognition();
      }
    } catch (error) {
      _onError?.call('Invalid Cartesia stream event: $error');
    }
  }

  void _queuePcmChunk(Uint8List bytes) {
    final audioContext = _audioContext;
    if (audioContext == null || bytes.length < 4) return;
    final sampleCount = bytes.length ~/ 4;
    final byteData = ByteData.sublistView(bytes);
    final samples = Float32List(sampleCount);
    for (var index = 0; index < sampleCount; index++) {
      samples[index] = byteData.getFloat32(index * 4, Endian.little);
    }
    final buffer = audioContext.createBuffer(1, sampleCount, _sampleRate);
    buffer.copyToChannel(samples.toJS, 0);
    final source = audioContext.createBufferSource();
    source.buffer = buffer;
    source.connect(audioContext.destination);
    final startAt = _playAt > audioContext.currentTime + 0.02
        ? _playAt
        : audioContext.currentTime + 0.02;
    source.start(startAt);
    _playAt = startAt + buffer.duration;
  }

  void _resumeAfterPlayback() {
    final audioContext = _audioContext;
    final waitSeconds = audioContext == null
        ? 0.0
        : (_playAt - audioContext.currentTime).clamp(0.0, 30.0);
    _resumeTimer?.cancel();
    _resumeTimer = Timer(
      Duration(milliseconds: (waitSeconds * 1000).ceil() + 80),
      () {
        _speaking = false;
        _startRecognition();
      },
    );
  }

  @override
  Future<void> stop() async {
    _active = false;
    _speaking = false;
    _resumeTimer?.cancel();
    _resumeTimer = null;
    try {
      _recognition?.abort();
    } catch (_) {}
    _recognition = null;
    try {
      _socket?.close(1000, 'session completed');
    } catch (_) {}
    _socket = null;
    final audioContext = _audioContext;
    _audioContext = null;
    if (audioContext != null) {
      await audioContext.close().toDart;
    }
    _config = null;
    _onTranscript = null;
    _onStatus = null;
    _onError = null;
  }
}
