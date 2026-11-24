import 'package:web/web.dart' as web;

import 'guitar_metronome_audio_service.dart';

GuitarMetronomeAudioService createGuitarMetronomeAudioService() =>
    WebGuitarMetronomeAudioService();

/// 単一 AudioContext を再利用してクリック音を生成する Web Audio API 実装。
class WebGuitarMetronomeAudioService implements GuitarMetronomeAudioService {
  web.AudioContext? _context;
  bool _disposed = false;

  @override
  bool get isAudioSupported => true;

  @override
  void playClick({required bool accent}) {
    if (_disposed) return;
    try {
      final context = _context ??= web.AudioContext();
      if (context.state == 'suspended') {
        context.resume();
      }
      final osc = context.createOscillator();
      final gain = context.createGain();
      osc.connect(gain);
      gain.connect(context.destination);

      final now = context.currentTime;
      osc.frequency.value = accent ? 1000.0 : 720.0;
      gain.gain.setValueAtTime(accent ? 0.30 : 0.18, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.045);
      osc.start(now);
      osc.stop(now + 0.05);
    } catch (_) {
      // 自動再生制限などで Web Audio が使えない環境でも視覚メトロノームは継続する。
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final context = _context;
    _context = null;
    if (context == null) return;
    try {
      context.close();
    } catch (_) {}
  }
}
