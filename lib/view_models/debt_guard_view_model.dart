import 'package:flutter/foundation.dart';

import '../data/repositories/debt_guard_repository.dart';
import '../domain/models/debt_guard_emotion.dart';
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
  List<DebtGuardEvent> _labelledEvents = const <DebtGuardEvent>[];
  bool _labelledEventsLoaded = false;
  bool _labelledEventsFailed = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  DebtGuardDailySnapshot get snapshot => _snapshot;
  List<DebtGuardEvent> get events => _snapshot.events;
  bool get isAuthenticated => _userId != null;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  /// Which feelings precede violations over the last four weeks.
  ///
  /// Stays `unavailable` until the labelled history has actually been read,
  /// so "could not look" is never shown as "no pattern".
  /// True only after a read of the labelled history was attempted and failed.
  bool get emotionInsightFailed => _labelledEventsFailed;

  DebtGuardEmotionInsight get emotionInsight => _labelledEventsLoaded
      ? DebtGuardEmotionInsight.fromEvents(
          events: _labelledEvents,
          now: _clock(),
        )
      : const DebtGuardEmotionInsight.unavailable();

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
    await _loadLabelledEvents();
  }

  /// The trend is supplementary: failing to read it must not block today's
  /// record keeping, so it has its own error boundary and no error banner.
  Future<void> _loadLabelledEvents() async {
    try {
      _labelledEvents = await _repository.loadLabelledEvents(
        userId: _userId!,
        since: DebtGuardEmotionInsight.windowStart(_clock()),
      );
      _labelledEventsLoaded = true;
      _labelledEventsFailed = false;
    } catch (_) {
      _labelledEvents = const <DebtGuardEvent>[];
      _labelledEventsLoaded = false;
      _labelledEventsFailed = true;
    }
    notifyListeners();
  }

  Future<bool> record({
    required String ruleId,
    required DebtGuardEventType type,
    String? note,
    DebtGuardEmotion? emotion,
  }) async {
    if (_userId == null || _isSaving || !_isKnownRule(ruleId)) return false;
    return _append([
      DebtGuardEventDraft(
        ruleId: ruleId,
        type: type,
        note: note,
        // A routine check-in is not an urge and never carries a feeling.
        emotion: type == DebtGuardEventType.checkIn ? null : emotion,
      ),
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
      if (_labelledEventsLoaded) {
        _labelledEvents = <DebtGuardEvent>[
          ..._labelledEvents,
          for (final event in inserted)
            if (event.emotion != null) event,
        ];
      }
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
