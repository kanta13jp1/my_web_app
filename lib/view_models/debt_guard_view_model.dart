import 'package:flutter/foundation.dart';

import '../data/repositories/debt_guard_repository.dart';
import '../domain/models/debt_guard_rule.dart';
import '../domain/use_cases/build_debt_guard_daily_snapshot_use_case.dart';

typedef DebtGuardClock = DateTime Function();

class DebtGuardViewModel extends ChangeNotifier {
  DebtGuardViewModel({
    required DebtGuardRepository repository,
    required String? userId,
    BuildDebtGuardDailySnapshotUseCase buildSnapshot =
        const BuildDebtGuardDailySnapshotUseCase(),
    DebtGuardClock clock = DateTime.now,
  })  : _repository = repository,
        _userId = userId,
        _buildSnapshot = buildSnapshot,
        _clock = clock,
        _snapshot = buildSnapshot(rules: debtGuardRules, events: const []);

  final DebtGuardRepository _repository;
  final String? _userId;
  final BuildDebtGuardDailySnapshotUseCase _buildSnapshot;
  final DebtGuardClock _clock;

  DebtGuardDailySnapshot _snapshot;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  DebtGuardDailySnapshot get snapshot => _snapshot;
  List<DebtGuardEvent> get events => _snapshot.events;
  bool get isAuthenticated => _userId != null;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_userId == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final events = await _repository.loadDailyEvents(
        userId: _userId,
        date: _clock(),
      );
      _snapshot = _buildSnapshot(rules: debtGuardRules, events: events);
    } catch (_) {
      _errorMessage = '禁止事項の記録を読み込めませんでした。もう一度お試しください。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> record({
    required String ruleId,
    required DebtGuardEventType type,
    String? note,
  }) async {
    if (_userId == null || _isSaving || !_isKnownRule(ruleId)) return false;
    return _append([
      DebtGuardEventDraft(ruleId: ruleId, type: type, note: note),
    ]);
  }

  Future<bool> checkInAllUnrecorded() async {
    if (_userId == null || _isSaving) return false;
    final drafts = <DebtGuardEventDraft>[
      for (final rule in debtGuardRules)
        if (_snapshot.statusFor(rule.id) == DebtGuardRuleStatus.unrecorded)
          DebtGuardEventDraft(
            ruleId: rule.id,
            type: DebtGuardEventType.checkIn,
          ),
    ];
    if (drafts.isEmpty) return true;
    return _append(drafts);
  }

  Future<bool> _append(List<DebtGuardEventDraft> drafts) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final inserted = await _repository.appendEvents(
        userId: _userId!,
        date: _clock(),
        events: drafts,
      );
      final events = <DebtGuardEvent>[..._snapshot.events, ...inserted]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _snapshot = _buildSnapshot(rules: debtGuardRules, events: events);
      return true;
    } catch (_) {
      _errorMessage = '記録を保存できませんでした。通信状態を確認して再度お試しください。';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  bool _isKnownRule(String ruleId) =>
      debtGuardRules.any((rule) => rule.id == ruleId);
}
