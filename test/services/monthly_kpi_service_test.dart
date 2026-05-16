import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/monthly_kpi_service.dart';

void main() {
  test('buildLedger calculates progress, current month delta and MoM', () {
    const service = MonthlyKpiService();
    final ledger = service.buildLedger(
      now: DateTime(2026, 5, 11),
      goals: [
        {
          'id': 'goal-a',
          'title': '売上導線を作る',
          'level': 'small',
          'category': 'finance',
          'progress': 70,
          'status': 'active',
          'priority': 5,
          'target_date': '2026-05-25',
        },
        {
          'id': 'goal-b',
          'title': '月次レビューを定着させる',
          'level': 'medium',
          'category': 'career',
          'progress': 30,
          'status': 'active',
          'priority': 3,
          'target_date': '2026-07-01',
        },
      ],
      reviews: [
        {
          'goal_id': 'goal-a',
          'progress_before': 40,
          'progress_after': 45,
          'created_at': '2026-04-20T10:00:00Z',
        },
        {
          'goal_id': 'goal-b',
          'progress_before': 20,
          'progress_after': 25,
          'created_at': '2026-04-21T10:00:00Z',
        },
        {
          'goal_id': 'goal-a',
          'progress_before': 50,
          'progress_after': 70,
          'created_at': '2026-05-10T10:00:00Z',
        },
      ],
    );

    expect(ledger.goalCount, 2);
    expect(ledger.averageProgress, 50);
    expect(ledger.currentMonthDeltaAverage, 10);
    expect(ledger.previousMonthDeltaAverage, 5);
    expect(ledger.monthOverMonthDelta, 5);
    expect(ledger.atRiskGoals(DateTime(2026, 5, 11)).single.goal.id, 'goal-a');
  });

  test('fallbackAdvice returns focused guidance for an empty ledger', () {
    const service = MonthlyKpiService();
    final ledger = service.buildLedger(
      now: DateTime(2026, 5, 11),
      goals: const [],
      reviews: const [],
    );

    expect(service.fallbackAdvice(ledger, DateTime(2026, 5, 11)), isNotEmpty);
  });
}
