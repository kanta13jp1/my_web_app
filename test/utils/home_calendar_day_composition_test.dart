import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/home_daily_cashflow_summary.dart';
import 'package:my_web_app/utils/home_calendar_day_composition.dart';
import 'package:my_web_app/utils/home_calendar_visible_range.dart';

String _dateKey(DateTime date) =>
    DateFormat('yyyy-MM-dd').format(DateTime(date.year, date.month, date.day));

void main() {
  test('preloaded abstinence skips fetch; null fetches once', () async {
    final range = HomeCalendarVisibleRange(
      monthAnchor: DateTime(2026, 11, 1),
      startDay: DateTime(2026, 11, 1),
      endDay: DateTime(2026, 11, 2),
    );
    var fetchCount = 0;

    final preloaded = await loadHomeCalendarDays<String>(
      range: range,
      now: DateTime(2026, 11, 1, 9),
      dateKeyFor: _dateKey,
      dailyStatusByDate: const <String, HomeCalendarDailyStatusInput>{},
      pendingCriticalTaskMap: const <String, int>{},
      cashflowByDate: const <String, HomeDailyCashflowSummary>{},
      tasksByDate: const <String, List<String>>{},
      abstinenceByDate: const <String, HomeCalendarAbstinenceInput>{},
      fetchAbstinenceByDate: (_, __) async {
        fetchCount += 1;
        return const <String, HomeCalendarAbstinenceInput>{};
      },
    );

    expect(fetchCount, 0);
    expect(preloaded, hasLength(2));

    DateTime? capturedStart;
    DateTime? capturedEnd;
    await loadHomeCalendarDays<String>(
      range: range,
      now: DateTime(2026, 11, 1, 9),
      dateKeyFor: _dateKey,
      dailyStatusByDate: const <String, HomeCalendarDailyStatusInput>{},
      pendingCriticalTaskMap: const <String, int>{},
      cashflowByDate: const <String, HomeDailyCashflowSummary>{},
      tasksByDate: const <String, List<String>>{},
      fetchAbstinenceByDate: (start, end) async {
        fetchCount += 1;
        capturedStart = start;
        capturedEnd = end;
        return const <String, HomeCalendarAbstinenceInput>{};
      },
    );

    expect(fetchCount, 1);
    expect(capturedStart, DateTime(2026, 11, 1));
    expect(capturedEnd, DateTime(2026, 11, 2));
  });

  test('composes flags, cashflow, and defensive task copies', () async {
    final range = HomeCalendarVisibleRange(
      monthAnchor: DateTime(2026, 11, 1),
      startDay: DateTime(2026, 10, 31),
      endDay: DateTime(2026, 11, 2),
    );
    final sourceTasks = <String>['task-a'];
    final days = await loadHomeCalendarDays<String>(
      range: range,
      now: DateTime(2026, 11, 1, 12),
      dateKeyFor: _dateKey,
      dailyStatusByDate: const {
        '2026-10-31': HomeCalendarDailyStatusInput(
          morningBriefingDone: true,
          balanceCheckDone: true,
        ),
      },
      pendingCriticalTaskMap: const {'2026-11-01': 2},
      cashflowByDate: const {
        '2026-11-01': HomeDailyCashflowSummary(
          incomeTotal: 500,
          incomeCount: 1,
        ),
      },
      tasksByDate: {'2026-11-01': sourceTasks},
      abstinenceByDate: const {
        '2026-10-31': HomeCalendarAbstinenceInput(
          enabledCount: 1,
          disciplineRepCount: 1,
          enabledLabels: ['SNS'],
        ),
      },
      fetchAbstinenceByDate: (_, __) async =>
          const <String, HomeCalendarAbstinenceInput>{},
      additionalDebtViolationDates: const {'2026-11-01'},
    );

    expect(days, hasLength(3));
    expect(days[0].isCurrentMonth, isFalse);
    expect(days[0].isSaturday, isTrue);
    expect(days[0].missingItems, isEmpty);

    expect(days[1].isToday, isTrue);
    expect(days[1].isFuture, isFalse);
    expect(days[1].hasAdditionalDebtViolation, isTrue);
    expect(days[1].cashflow.incomeTotal, 500);
    expect(days[1].tasks, ['task-a']);
    days[1].tasks.add('mutated');
    expect(sourceTasks, ['task-a']);

    expect(days[2].isFuture, isTrue);
    expect(days[2].missingItems, isEmpty);
  });

  test('buildHomeCalendarMissingItems matches future and incomplete rules', () {
    expect(
      buildHomeCalendarMissingItems(
        isFuture: true,
        morningDone: false,
        balanceDone: false,
        pendingCriticalTaskCount: 3,
        hasProtection: false,
      ),
      isEmpty,
    );

    expect(
      buildHomeCalendarMissingItems(
        isFuture: false,
        morningDone: false,
        balanceDone: false,
        pendingCriticalTaskCount: 2,
        hasProtection: false,
      ),
      const [
        'モーニング・ブリーフィング',
        '口座残高確認',
        '必須タスク 2件',
        '禁欲ガード設定',
      ],
    );
  });

  test('buildHomeCalendarRelapsePreventionAction covers all 7 branches', () {
    expect(
      buildHomeCalendarRelapsePreventionAction(
        isFuture: true,
        hasSlip: true,
        slippedCandidates: const [],
        hasProtection: false,
        disciplineRepCount: 0,
        morningDone: false,
        balanceDone: false,
      ),
      '前日までの逸脱傾向を見て、禁止対象を1件だけ先に固定する。',
    );

    final candidates = [
      const HomeCalendarSlipCandidate(
        label: 'A',
        replacementAction: 'doA',
        slipCount: 1,
      ),
      const HomeCalendarSlipCandidate(
        label: 'B',
        replacementAction: 'doB',
        slipCount: 4,
      ),
    ];
    expect(
      buildHomeCalendarRelapsePreventionAction(
        isFuture: false,
        hasSlip: true,
        slippedCandidates: candidates,
        hasProtection: false,
        disciplineRepCount: 0,
        morningDone: false,
        balanceDone: false,
      ),
      'Bが崩れやすい日。doB',
    );
    expect(candidates.first.label, 'A');

    expect(
      buildHomeCalendarRelapsePreventionAction(
        isFuture: false,
        hasSlip: false,
        slippedCandidates: const [],
        hasProtection: false,
        disciplineRepCount: 0,
        morningDone: false,
        balanceDone: false,
      ),
      '朝いちで禁止対象を1件だけ固定して、先に逃げ道を塞ぐ。',
    );

    expect(
      buildHomeCalendarRelapsePreventionAction(
        isFuture: false,
        hasSlip: false,
        slippedCandidates: const [],
        hasProtection: true,
        disciplineRepCount: 0,
        morningDone: false,
        balanceDone: false,
      ),
      '今日はまだ我慢の実績がありません。買わない・開かないを1回記録する。',
    );

    expect(
      buildHomeCalendarRelapsePreventionAction(
        isFuture: false,
        hasSlip: false,
        slippedCandidates: const [],
        hasProtection: true,
        disciplineRepCount: 1,
        morningDone: false,
        balanceDone: false,
      ),
      '朝の最初にブリーフィングを実施し、優先順位を固定する。',
    );

    expect(
      buildHomeCalendarRelapsePreventionAction(
        isFuture: false,
        hasSlip: false,
        slippedCandidates: const [],
        hasProtection: true,
        disciplineRepCount: 1,
        morningDone: true,
        balanceDone: false,
      ),
      '口座残高確認を先に終えて、意思決定を数字に戻す。',
    );

    expect(
      buildHomeCalendarRelapsePreventionAction(
        isFuture: false,
        hasSlip: false,
        slippedCandidates: const [],
        hasProtection: true,
        disciplineRepCount: 1,
        morningDone: true,
        balanceDone: true,
      ),
      '同じ禁止対象を維持し、夜に逸脱ゼロを確認して日次を閉じる。',
    );
  });
}
