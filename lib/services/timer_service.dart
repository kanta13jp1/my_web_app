import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_timer.dart';

/// タイマーサービス
/// タイマーの開始、一時停止、停止、再開などを管理
class TimerService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // アクティブなタイマー
  AppTimer? _activeTimer;

  // カウントダウン用のTimer
  Timer? _countdownTimer;

  // 残り時間（秒）
  int _remainingSeconds = 0;

  AppTimer? get activeTimer => _activeTimer;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _activeTimer?.status == TimerStatus.running;
  bool get isPaused => _activeTimer?.status == TimerStatus.paused;
  bool get hasActiveTimer => _activeTimer != null;

  /// タイマーを開始
  Future<void> startTimer({
    required String name,
    required int durationSeconds,
    int? noteId,
    bool soundNotification = true,
    bool browserNotification = true,
    bool autoSave = false,
  }) async {
    try {
      // 既存のタイマーがあれば停止
      if (_activeTimer != null) {
        await stopTimer();
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Supabaseに保存
      final response = await _supabase.from('timers').insert({
        'user_id': userId,
        'note_id': noteId,
        'name': name,
        'duration_seconds': durationSeconds,
        'started_at': DateTime.now().toIso8601String(),
        'status': 'running',
        'sound_notification': soundNotification,
        'browser_notification': browserNotification,
        'auto_save': autoSave,
      }).select().single();

      // タイマー作成
      _activeTimer = AppTimer.fromJson(response);
      _remainingSeconds = durationSeconds;

      // カウントダウン開始
      _startCountdown();

      notifyListeners();
    } catch (e) {
      debugPrint('⏱️ Error starting timer: $e');
      rethrow;
    }
  }

  /// カウントダウン開始
  void _startCountdown() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_activeTimer?.status != TimerStatus.running) {
          timer.cancel();
          return;
        }

        _remainingSeconds--;
        notifyListeners();

        // 完了
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _onTimerComplete();
        }
      },
    );
  }

  /// タイマー完了時の処理
  Future<void> _onTimerComplete() async {
    if (_activeTimer == null) return;

    try {
      // ステータス更新
      await _supabase.from('timers').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', _activeTimer!.id);

      _activeTimer = _activeTimer!.copyWith(
        status: TimerStatus.completed,
        completedAt: DateTime.now(),
      );

      // 通知
      if (_activeTimer!.soundNotification) {
        _playSoundNotification();
      }
      if (_activeTimer!.browserNotification) {
        await _showBrowserNotification();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('⏱️ Error completing timer: $e');
    }
  }

  /// 一時停止
  Future<void> pauseTimer() async {
    if (_activeTimer == null || _activeTimer!.status != TimerStatus.running) {
      return;
    }

    try {
      await _supabase.from('timers').update({
        'status': 'paused',
      }).eq('id', _activeTimer!.id);

      _activeTimer = _activeTimer!.copyWith(status: TimerStatus.paused);
      _countdownTimer?.cancel();
      notifyListeners();
    } catch (e) {
      debugPrint('⏱️ Error pausing timer: $e');
    }
  }

  /// 再開
  Future<void> resumeTimer() async {
    if (_activeTimer == null || _activeTimer!.status != TimerStatus.paused) {
      return;
    }

    try {
      await _supabase.from('timers').update({
        'status': 'running',
      }).eq('id', _activeTimer!.id);

      _activeTimer = _activeTimer!.copyWith(status: TimerStatus.running);
      _startCountdown();
      notifyListeners();
    } catch (e) {
      debugPrint('⏱️ Error resuming timer: $e');
    }
  }

  /// 停止
  Future<void> stopTimer() async {
    if (_activeTimer == null) return;

    try {
      await _supabase.from('timers').update({
        'status': 'stopped',
      }).eq('id', _activeTimer!.id);

      _countdownTimer?.cancel();
      _activeTimer = null;
      _remainingSeconds = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('⏱️ Error stopping timer: $e');
    }
  }

  /// リセット（再スタート）
  Future<void> resetTimer() async {
    if (_activeTimer == null) return;

    final name = _activeTimer!.name;
    final durationSeconds = _activeTimer!.durationSeconds;
    final noteId = _activeTimer!.noteId;
    final soundNotification = _activeTimer!.soundNotification;
    final browserNotification = _activeTimer!.browserNotification;
    final autoSave = _activeTimer!.autoSave;

    await stopTimer();
    await startTimer(
      name: name,
      durationSeconds: durationSeconds,
      noteId: noteId,
      soundNotification: soundNotification,
      browserNotification: browserNotification,
      autoSave: autoSave,
    );
  }

  /// サウンド通知
  void _playSoundNotification() {
    // Web環境でHTML AudioElementを使用してサウンドを再生
    // TODO: assets/sounds/timer_complete.mp3 を追加して再生
    debugPrint('⏱️ Playing sound notification');
  }

  /// ブラウザ通知
  Future<void> _showBrowserNotification() async {
    // Web Notification API を使用
    // TODO: Web通知の実装
    debugPrint('⏱️ Showing browser notification');
  }

  /// 残り時間をフォーマット（MM:SS）
  String formatRemainingTime() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 進捗率（0.0 - 1.0）
  double get progress {
    if (_activeTimer == null) return 0.0;
    final total = _activeTimer!.durationSeconds;
    if (total == 0) return 0.0;
    return (_remainingSeconds / total).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
