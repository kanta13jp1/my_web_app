import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../domain/voice_clone_consent_models.dart';

VoiceConsentAudioRecorder createVoiceConsentAudioRecorder() =>
    _WebVoiceConsentAudioRecorder();

class _WebVoiceConsentAudioRecorder implements VoiceConsentAudioRecorder {
  web.MediaRecorder? _recorder;
  web.MediaStream? _stream;
  final List<JSObject> _chunks = <JSObject>[];
  final Stopwatch _stopwatch = Stopwatch();
  Completer<void>? _stopCompleter;
  String _selectedMime = 'audio/webm';

  @override
  bool get isMicrophoneSupported => true;

  @override
  Future<void> startRecording() async {
    await _cleanupMedia();
    _chunks.clear();
    _stopwatch
      ..reset()
      ..start();

    final mediaDevices = web.window.navigator.mediaDevices;
    final constraints = web.MediaStreamConstraints(audio: true.toJS);
    final stream = await mediaDevices.getUserMedia(constraints).toDart;
    _stream = stream;

    String mime = 'audio/webm;codecs=opus';
    if (!web.MediaRecorder.isTypeSupported(mime)) {
      mime = 'audio/webm';
      if (!web.MediaRecorder.isTypeSupported(mime)) {
        mime = 'audio/mp4';
        if (!web.MediaRecorder.isTypeSupported(mime)) {
          mime = '';
        }
      }
    }
    _selectedMime = mime.isEmpty ? 'audio/webm' : mime.split(';').first;

    final options = mime.isNotEmpty
        ? web.MediaRecorderOptions(mimeType: mime)
        : web.MediaRecorderOptions();
    final recorder = web.MediaRecorder(stream, options);
    _recorder = recorder;

    recorder.addEventListener(
      'dataavailable',
      (final web.Event event) {
        final blobEvent = event as web.BlobEvent;
        final data = blobEvent.data;
        if (data.size > 0) {
          _chunks.add(data as JSObject);
        }
      }.toJS,
    );

    final completer = Completer<void>();
    _stopCompleter = completer;
    recorder.addEventListener(
      'stop',
      (final web.Event _) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }.toJS,
    );

    recorder.start(250);
  }

  @override
  Future<VoiceAudioCaptureResult> stopRecording() async {
    final recorder = _recorder;
    if (recorder == null) {
      throw StateError('No active recording session');
    }
    _stopwatch.stop();
    final durationMs = _stopwatch.elapsedMilliseconds;

    final completer = _stopCompleter;
    if (recorder.state != 'inactive') {
      recorder.stop();
    } else if (completer != null && !completer.isCompleted) {
      completer.complete();
    }

    if (completer != null) {
      await completer.future.timeout(const Duration(seconds: 5));
    }

    final blob = web.Blob(
      _chunks.toJS,
      web.BlobPropertyBag(type: _selectedMime),
    );
    final arrayBuffer = await blob.arrayBuffer().toDart;
    final Uint8List bytes = arrayBuffer.toDart.asUint8List();
    await _cleanupMedia();

    return VoiceAudioCaptureResult(
      bytes: bytes,
      mimeType: _selectedMime,
      durationMs: durationMs,
    );
  }

  Future<void> _cleanupMedia() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null && recorder.state != 'inactive') {
      recorder.stop();
    }
    final stream = _stream;
    _stream = null;
    if (stream != null) {
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
    }
  }

  @override
  Future<void> dispose() async {
    _stopwatch.stop();
    await _cleanupMedia();
  }
}
