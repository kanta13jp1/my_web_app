import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/procrastination_reset_gateway.dart';
import '../domain/procrastination_reset_models.dart';

enum ProcrastinationResetLoadStatus { initial, loading, ready, failure }

class ProcrastinationResetViewModel extends ChangeNotifier {
  ProcrastinationResetViewModel({
    required ProcrastinationResetGateway gateway,
    BuildProcrastinationPlan planBuilder = const BuildProcrastinationPlan(),
    DateTime Function()? now,
  })  : _gateway = gateway,
        _planBuilder = planBuilder,
        _now = now ?? DateTime.now;

  static const sessionDurationSeconds = 5 * 60;

  final ProcrastinationResetGateway _gateway;
  final BuildProcrastinationPlan _planBuilder;
  final DateTime Function() _now;

  ProcrastinationResetLoadStatus _loadStatus =
      ProcrastinationResetLoadStatus.initial;
  ProcrastinationResetSnapshot _snapshot = const ProcrastinationResetSnapshot();
  Timer? _timer;
  int _remainingSeconds = sessionDurationSeconds;
  bool _isSaving = false;
  String? _errorMessage;
  String? _lastCompletedAction;

  ProcrastinationResetLoadStatus get loadStatus => _loadStatus;
  ProcrastinationResetSession? get session => _snapshot.session;
  int get completedCount => _snapshot.completedCount;
  int get remainingSeconds => _remainingSeconds;
  bool get isSaving => _isSaving;
  bool get isTimerComplete =>
      session?.hasStarted == true && _remainingSeconds == 0;
  String? get errorMessage => _errorMessage;
  String? get lastCompletedAction => _lastCompletedAction;

  Future<void> load() async {
    _loadStatus = ProcrastinationResetLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _snapshot = await _gateway.load();
      _loadStatus = ProcrastinationResetLoadStatus.ready;
      _syncTimer();
    } catch (_) {
      _loadStatus = ProcrastinationResetLoadStatus.failure;
      _errorMessage = '保存したプランを読み込めませんでした。もう一度お試しください。';
    }
    notifyListeners();
  }

  Future<bool> createPlan({
    required String task,
    required String fiveMinuteAction,
    required String firstMove,
    required DistractionBarrier barrier,
  }) async {
    if (_isSaving) return false;
    _errorMessage = null;
    ProcrastinationResetSession plan;
    try {
      plan = _planBuilder(
        task: task,
        fiveMinuteAction: fiveMinuteAction,
        firstMove: firstMove,
        barrier: barrier,
        createdAt: _now(),
      );
    } on ProcrastinationPlanValidationException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return false;
    }

    final next = ProcrastinationResetSnapshot(
      session: plan,
      completedCount: _snapshot.completedCount,
      lastCompletedAt: _snapshot.lastCompletedAt,
    );
    return _save(next);
  }

  Future<bool> startSession() async {
    final current = session;
    if (current == null || current.hasStarted || _isSaving) return false;
    final next = ProcrastinationResetSnapshot(
      session: current.start(_now()),
      completedCount: _snapshot.completedCount,
      lastCompletedAt: _snapshot.lastCompletedAt,
    );
    final saved = await _save(next);
    if (saved) _syncTimer();
    return saved;
  }

  Future<bool> completeSession() async {
    final current = session;
    if (current == null || _isSaving) return false;
    final completedAt = _now();
    final next = ProcrastinationResetSnapshot(
      completedCount: _snapshot.completedCount + 1,
      lastCompletedAt: completedAt,
    );
    final saved = await _save(next);
    if (saved) {
      _timer?.cancel();
      _remainingSeconds = sessionDurationSeconds;
      _lastCompletedAction = current.fiveMinuteAction;
      notifyListeners();
    }
    return saved;
  }

  Future<bool> resetSession() async {
    if (session == null || _isSaving) return false;
    final next = ProcrastinationResetSnapshot(
      completedCount: _snapshot.completedCount,
      lastCompletedAt: _snapshot.lastCompletedAt,
    );
    final saved = await _save(next);
    if (saved) {
      _timer?.cancel();
      _remainingSeconds = sessionDurationSeconds;
      notifyListeners();
    }
    return saved;
  }

  void clearCompletionNotice() {
    if (_lastCompletedAction == null) return;
    _lastCompletedAction = null;
    notifyListeners();
  }

  Future<bool> _save(ProcrastinationResetSnapshot next) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _gateway.save(next);
      _snapshot = next;
      return true;
    } catch (_) {
      _errorMessage = '端末内に保存できませんでした。空き容量やブラウザ設定をご確認ください。';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    final startedAt = session?.startedAt;
    if (startedAt == null) {
      _remainingSeconds = sessionDurationSeconds;
      return;
    }
    _updateRemaining(startedAt);
    if (_remainingSeconds == 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining(startedAt);
      notifyListeners();
      if (_remainingSeconds == 0) _timer?.cancel();
    });
  }

  void _updateRemaining(DateTime startedAt) {
    final elapsed = _now().difference(startedAt).inSeconds;
    final next = sessionDurationSeconds - elapsed;
    _remainingSeconds = next.clamp(0, sessionDurationSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
