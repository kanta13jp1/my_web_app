import 'dart:async';
import 'package:flutter/foundation.dart';
import 'browser_reminder_platform.dart';

/// Page-session reminder only. No persisted opt-in and no server-side push.
class BrowserReminderController extends ChangeNotifier {
  BrowserReminderController({
    required this.supported,
    required String Function() readPermission,
    required Future<String> Function() requestPermission,
    required Future<void> Function() showReminder,
    DateTime Function()? now,
  })  : _readPermission = readPermission,
        _requestPermission = requestPermission,
        _showReminder = showReminder,
        _now = now ?? DateTime.now;

  static final BrowserReminderController instance = _create();
  static BrowserReminderController _create() {
    final platform = BrowserReminderPlatform();
    return BrowserReminderController(
      supported: platform.supported,
      readPermission: () => platform.permission,
      requestPermission: platform.requestPermission,
      showReminder: platform.showReminder,
    );
  }

  final bool supported;
  final String Function() _readPermission;
  final Future<String> Function() _requestPermission;
  final Future<void> Function() _showReminder;
  final DateTime Function() _now;
  static const intervals = [5, 10, 15, 30];
  int intervalMinutes = 5;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  bool busy = false;
  bool _delivering = false;
  String? message;
  DateTime? nextAt;
  DateTime? lastRequestedAt;
  bool get running => _timer != null;
  String get permission => supported ? _readPermission() : 'unsupported';

  void setInterval(int minutes) {
    if (!intervals.contains(minutes) || busy) return;
    intervalMinutes = minutes;
    if (running) _schedule();
    notifyListeners();
  }

  Future<bool> _allow() async {
    if (!supported) {
      message = 'HTTPS対応のデスクトップブラウザで利用してください。';
      return false;
    }
    var result = permission;
    if (result == 'default') result = await _requestPermission();
    if (result != 'granted') {
      message = result == 'denied'
          ? '通知がブロックされています。ブラウザのサイト設定で変更できます。'
          : '通知は許可されていません。開始していません。';
      return false;
    }
    return true;
  }

  /// Call only from an explicit UI action, preserving browser user activation.
  Future<void> start() async {
    if (busy || running || _disposed) return;
    final generation = ++_generation;
    busy = true;
    message = null;
    notifyListeners();
    try {
      if (await _allow() && generation == _generation && !_disposed) {
        _schedule();
        message = 'このページを開いている間、約$intervalMinutes分おきに通知します。';
      }
    } catch (_) {
      if (_disposed || generation != _generation) return;
      message = '通知を開始できませんでした。サイトの通知設定を確認してください。';
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void _schedule() {
    _timer?.cancel();
    nextAt = _now().add(Duration(minutes: intervalMinutes));
    _timer = Timer.periodic(Duration(minutes: intervalMinutes), (_) {
      unawaited(_deliver());
    });
  }

  Future<void> _deliver() async {
    if (_delivering || !running || _disposed) return;
    if (permission != 'granted') {
      stop();
      message = '通知の許可がなくなったため停止しました。';
      notifyListeners();
      return;
    }
    final generation = _generation;
    _delivering = true;
    try {
      await _showReminder();
      if (generation != _generation || _disposed) return;
      lastRequestedAt = _now();
      nextAt = _now().add(Duration(minutes: intervalMinutes));
    } catch (_) {
      if (generation != _generation || _disposed) return;
      stop();
      message = '通知を送れなかったため停止しました。設定を確認して再開してください。';
    } finally {
      _delivering = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> testNotification() async {
    if (busy || _disposed) return;
    final generation = ++_generation;
    busy = true;
    message = null;
    notifyListeners();
    try {
      if (await _allow() && generation == _generation && !_disposed) {
        await _showReminder();
        if (generation != _generation || _disposed) return;
        lastRequestedAt = _now();
        message = 'テスト通知を要求しました。表示されない場合はWindowsとブラウザの通知設定を確認してください。';
      }
    } catch (_) {
      if (_disposed || generation != _generation) return;
      message = 'テスト通知を送れませんでした。サイトの通知設定を確認してください。';
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void refreshPermission() {
    if (_disposed) return;
    if (running && permission != 'granted') stop();
    notifyListeners();
  }

  void stop() {
    ++_generation;
    _timer?.cancel();
    _timer = null;
    nextAt = null;
    busy = false;
    message = '停止中です。';
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
