import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/debt_guard_repository.dart';
import 'package:my_web_app/domain/models/debt_guard_rule.dart';
import 'package:my_web_app/view_models/debt_guard_view_model.dart';

void main() {
  group('DebtGuardViewModel', () {
    late _MemoryDebtGuardRepository repository;
    late DebtGuardViewModel viewModel;

    setUp(() {
      repository = _MemoryDebtGuardRepository();
      viewModel = DebtGuardViewModel(
        repository: repository,
        userId: 'user-1',
        clock: () => DateTime(2026, 8, 22, 10),
      );
    });

    tearDown(() => viewModel.dispose());

    test('loads today events and derives the summary', () async {
      repository.events.add(
        _storedEvent(1, 'gambling', DebtGuardEventType.violation),
      );

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.snapshot.violatedCount, 1);
      expect(viewModel.snapshot.unrecordedCount, 24);
      expect(viewModel.errorMessage, isNull);
    });

    test('checks in only unrecorded rules in one batch', () async {
      repository.events.addAll([
        _storedEvent(1, 'additional_borrowing', DebtGuardEventType.violation),
        _storedEvent(2, 'eating_out', DebtGuardEventType.checkIn),
      ]);
      await viewModel.load();

      expect(await viewModel.checkInAllUnrecorded(), isTrue);

      expect(repository.lastDrafts, hasLength(23));
      expect(viewModel.snapshot.keptCount, 24);
      expect(viewModel.snapshot.violatedCount, 1);
      expect(
        viewModel.snapshot.statusFor('additional_borrowing'),
        DebtGuardRuleStatus.violated,
      );
    });

    test('records a resisted urge and updates immediately', () async {
      await viewModel.load();

      final saved = await viewModel.record(
        ruleId: 'short_videos',
        type: DebtGuardEventType.urgeResisted,
        note: 'アプリを閉じて散歩した',
      );

      expect(saved, isTrue);
      expect(viewModel.snapshot.resistedUrgeCount, 1);
      expect(
        viewModel.snapshot.statusFor('short_videos'),
        DebtGuardRuleStatus.kept,
      );
      expect(viewModel.events.single.note, 'アプリを閉じて散歩した');
    });

    test('records starting a required action as weakening the bug', () async {
      await viewModel.load();

      final saved = await viewModel.record(
        ruleId: 'dishes_left_unwashed',
        type: DebtGuardEventType.requiredActionStarted,
        note: '皿を1枚洗った',
      );

      expect(saved, isTrue);
      expect(viewModel.snapshot.requiredActionStartedCount, 1);
      expect(viewModel.snapshot.bugWeakenedCount, 1);
      expect(
        viewModel.snapshot.statusFor('dishes_left_unwashed'),
        DebtGuardRuleStatus.kept,
      );
    });

    test('exposes a retryable save failure', () async {
      await viewModel.load();
      repository.failAppend = true;

      final saved = await viewModel.record(
        ruleId: 'alcohol',
        type: DebtGuardEventType.violation,
      );

      expect(saved, isFalse);
      expect(viewModel.isSaving, isFalse);
      expect(viewModel.errorMessage, contains('保存できませんでした'));
      expect(viewModel.snapshot.violatedCount, 0);
    });
  });
}

class _MemoryDebtGuardRepository implements DebtGuardRepository {
  final events = <DebtGuardEvent>[];
  List<DebtGuardEventDraft> lastDrafts = const [];
  bool failAppend = false;
  int _nextId = 100;

  @override
  Future<List<DebtGuardEvent>> loadDailyEvents({
    required String userId,
    required DateTime date,
  }) async {
    return List.of(events);
  }

  @override
  Future<List<DebtGuardEvent>> appendEvents({
    required String userId,
    required DateTime date,
    required List<DebtGuardEventDraft> events,
  }) async {
    if (failAppend) throw StateError('offline');
    lastDrafts = List.of(events);
    final inserted = [
      for (final draft in events)
        DebtGuardEvent(
          id: _nextId++,
          ruleId: draft.ruleId,
          type: draft.type,
          eventDate: DateTime(date.year, date.month, date.day),
          createdAt: date.add(Duration(microseconds: _nextId)),
          note: draft.note,
        ),
    ];
    this.events.addAll(inserted);
    return inserted;
  }
}

DebtGuardEvent _storedEvent(int id, String ruleId, DebtGuardEventType type) {
  return DebtGuardEvent(
    id: id,
    ruleId: ruleId,
    type: type,
    eventDate: DateTime(2026, 8, 22),
    createdAt: DateTime(2026, 8, 22, 9, id),
  );
}
